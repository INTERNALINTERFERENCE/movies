package handler

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"backend/internal/config"
	"backend/internal/models"

	"github.com/gorilla/websocket"
)

var (
	users = make(map[string]*websocket.Conn)
	mu    sync.RWMutex
)

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

	defer func(conn *websocket.Conn) {
		err := conn.Close()
		if err != nil {
			log.Printf("Failed to close WebSocket connection (client: %s): %v", r.RemoteAddr, err)
		}
		log.Printf("WebSocket connection (client: %s) closed", r.RemoteAddr)
	}(conn)

	user, err := initUser(conn)
	if err != nil {
		log.Printf("Failed to initialize user (client: %s): %v", r.RemoteAddr, err)
		return
	}

	mu.Lock()
	users[user.ConnectionId] = conn
	mu.Unlock()

	log.Printf("User successfully connected. ConnectionId: %s, Username: %s", user.ConnectionId, user.Username)

	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			log.Printf("Error reading message from user (ConnectionId: %s, Username: %s): %v", user.ConnectionId, user.Username, err)
			continue // ??  todo: think about continue later
		}

		mu.RLock()
		for id, uconn := range users {
			go func() {
				if err := uconn.WriteMessage(websocket.TextMessage, message); err != nil {
					log.Printf("Failed to broadcast message to user (ConnectionId: %s): %v", id, err)
				} else {
					log.Printf("Broadcasted message to user (ConnectionId: %s)", id)
				}
			}()
		}
		mu.RUnlock()
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
