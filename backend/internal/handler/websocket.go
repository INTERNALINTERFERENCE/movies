package handler

import (
	"backend/internal/metrics"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"backend/internal/config"
	"backend/internal/models"
	"backend/internal/room"

	"github.com/gorilla/websocket"
)

var roomManager = manager.NewRoomManager()
var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

func StreamHandler(w http.ResponseWriter, r *http.Request) {
	log.Printf("Attempting to establish connection from client: %s", r.RemoteAddr)

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Failed to upgrade HTTP connection to WebSocket (client: %s): %v", r.RemoteAddr, err)
		return
	}

	metrics.ActiveConnections.Inc()

	defer func(conn *websocket.Conn) {
		err := conn.Close()
		if err != nil {
			log.Printf("Failed to close WebSocket connection (client: %s): %v", r.RemoteAddr, err)
		}
		log.Printf("WebSocket connection (client: %s) closed", r.RemoteAddr)

		metrics.ActiveConnections.Dec()
	}(conn)

	user, err := initUser(conn)
	if err != nil {
		log.Printf("Failed to initialize user (client: %s): %v", r.RemoteAddr, err)
		return
	}

	roomManager.AddUser(user.RoomId, user, conn)
	defer roomManager.RemoveUser(user.RoomId, conn)

	readLoop(conn, user.RoomId)
}

func readLoop(conn *websocket.Conn, roomId string) {
	for {
		messageType, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("Error reading message (client disconnected unexpectedly): %v", err)
			} else {
				log.Printf("Client disconnected: %v", err)
			}
			break
		}

		log.Printf("Received message %s from client in room %s. Message type: %d", string(message), roomId, messageType)
		roomManager.BroadcastMessage(roomId, message)
	}
}

func initUser(conn *websocket.Conn) (models.User, error) {
	log.Printf("Waiting for user data (timeout: %v)", config.UserInitTimeout)

	var user models.User
	msgCh := make(chan []byte)
	timer := time.NewTimer(config.UserInitTimeout)

	go func() {
		_, message, err := conn.ReadMessage()
		if err != nil {
			log.Printf("Error reading message during user initialization: %v", err)
			return
		}
		msgCh <- message
	}()

	select {
	case msg := <-msgCh:
		if err := json.Unmarshal(msg, &user); err != nil {
			return user, fmt.Errorf("failed to parse JSON: %w", err)
		}
		return user, nil
	case <-timer.C:
		return user, fmt.Errorf("timeout: no data received within %v", config.UserInitTimeout)
	}
}
