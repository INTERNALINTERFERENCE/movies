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

func PingPongHandler(w http.ResponseWriter, r *http.Request) {
	clientIP := r.RemoteAddr
	log.Printf("[WebSocket] Attempting to establish connection from client: %s", clientIP)

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[WebSocket] Failed to upgrade HTTP connection to WebSocket (client: %s): %v", clientIP, err)
		return
	}

	defer conn.Close()

	user, err := initUser(conn)
	if err != nil {
		log.Printf("[WebSocket] Failed to initialize user (client: %s): %v", clientIP, err)
		return
	}

	mu.Lock()
	users[user.ConnectionId] = conn
	mu.Unlock()

	log.Printf("[WebSocket] User successfully connected - ConnectionId: %s, Username: %s, IP: %s", user.ConnectionId, user.Username, clientIP)

	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			log.Printf("[WebSocket] Error reading message from user (ConnectionId: %s, Username: %s): %v", user.ConnectionId, user.Username, err)
			return
		}

		log.Printf("[WebSocket] Message received from user (ConnectionId: %s, Username: %s): %s", user.ConnectionId, user.Username, string(message))

		if string(message) == "ping" {
			err := conn.WriteMessage(websocket.TextMessage, []byte("pong"))
			if err != nil {
				log.Printf("[WebSocket] Error sending 'pong' response to user (ConnectionId: %s, Username: %s): %v", user.ConnectionId, user.Username, err)
				return
			}
			log.Printf("[WebSocket] Sent 'pong' response to user (ConnectionId: %s, Username: %s)", user.ConnectionId, user.Username)
		}
		if string(message) == "play" {
			log.Printf("[WebSocket] Received 'play' request from user (ConnectionId: %s, Username: %s)", user.ConnectionId, user.Username)
			mu.RLock()
			for id, uconn := range users {
				err := uconn.WriteMessage(websocket.TextMessage, []byte("play"))
				if err != nil {
					log.Printf("[WebSocket] Failed to broadcast 'play' to user (ConnectionId: %s): %v", id, err)
				} else {
					log.Printf("[WebSocket] Broadcasted 'play' to user (ConnectionId: %s)", id)
				}
			}
			mu.RUnlock()
		}
	}
}

func initUser(conn *websocket.Conn) (models.User, error) {
	var user models.User

	log.Printf("[UserInit] Waiting for user data (timeout: %v)", config.UserInitTimeout)

	msgCh := make(chan []byte)
	timer := time.NewTimer(config.UserInitTimeout)

	go func() {
		_, message, err := conn.ReadMessage()
		if err != nil {
			log.Printf("[UserInit] Error reading message during user initialization: %v", err)
			return
		}
		log.Printf("[UserInit] Received user data: %s", string(message))
		msgCh <- message
	}()

	select {
	case msg := <-msgCh:
		if err := json.Unmarshal(msg, &user); err != nil {
			log.Printf("[UserInit] Error parsing user JSON data: %v, data: %s", err, string(msg))
			return user, fmt.Errorf("failed to parse JSON: %w", err)
		}
		log.Printf("[UserInit] User successfully initialized - ConnectionId: %s, Username: %s", user.ConnectionId, user.Username)
		return user, nil
	case <-timer.C:
		log.Printf("[UserInit] Timeout exceeded while waiting for user data (%v), connection closed", config.UserInitTimeout)
		conn.Close()
		return user, fmt.Errorf("timeout: no data received within %v", config.UserInitTimeout)
	}
}
