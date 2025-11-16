package handler

import (
	"backend/internal/config"
	"backend/internal/metrics"
	"backend/internal/models"
	"backend/internal/room"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type WebSocketHandler struct {
	roomManager *room.RoomManager
}

func NewWebSocketHandler(rm *room.RoomManager) *WebSocketHandler {
	return &WebSocketHandler{
		roomManager: rm,
	}
}

func (h *WebSocketHandler) StreamHandler(w http.ResponseWriter, r *http.Request) {
	log.Printf("Attempting to establish connection from client: %s", r.RemoteAddr)

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Failed to upgrade HTTP connection to WebSocket (client: %s): %v", r.RemoteAddr, err)
		return
	}
	metrics.ActiveConnections.Inc()

	user, err := initUser(conn)
	if err != nil {
		log.Printf("Failed to initialize user (client: %s): %v", r.RemoteAddr, err)
		// Ensure connection is closed and metrics are updated on init failure
		metrics.ActiveConnections.Dec()
		if closeErr := conn.Close(); closeErr != nil {
			log.Printf("Failed to close WebSocket connection on init error: %v", closeErr)
		}
		return
	}

	// Defer the decrement of active connections until the handler exits.
	// This is now placed after a successful user init.
	defer metrics.ActiveConnections.Dec()

	h.roomManager.AddUser(user.RoomId, user, conn)
	defer h.roomManager.RemoveUser(user.RoomId, user)

	h.readLoop(conn, user)
}

func (h *WebSocketHandler) readLoop(conn *websocket.Conn, user models.User) {
	for {
		messageType, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("Error reading message (client disconnected unexpectedly): %v", err)
			} else {
				log.Printf("Client %s disconnected: %v", user.ConnectionId, err)
			}
			break
		}

		log.Printf("Received message %s from client %s in room %s. Message type: %d", string(message), user.ConnectionId, user.RoomId, messageType)
		h.roomManager.RelayOrBroadcastMessage(user.RoomId, user.ConnectionId, message)
	}
}

func initUser(conn *websocket.Conn) (models.User, error) {
	log.Printf("Waiting for user data (timeout: %v)", config.UserInitTimeout)

	if err := conn.SetReadDeadline(time.Now().Add(config.UserInitTimeout)); err != nil {
		return models.User{}, fmt.Errorf("failed to set read deadline: %w", err)
	}

	_, message, err := conn.ReadMessage()
	if err != nil {
		return models.User{}, fmt.Errorf("failed to read init message: %w", err)
	}

	if err := conn.SetReadDeadline(time.Time{}); err != nil {
		log.Printf("Failed to reset read deadline: %v", err)
	}

	var user models.User
	if err := json.Unmarshal(message, &user); err != nil {
		return user, fmt.Errorf("failed to parse JSON: %w", err)
	}
	return user, nil
}
