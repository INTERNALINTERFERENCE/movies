package room

import (
	"backend/internal/config"
	"backend/internal/models"
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	MsgTypeUserListUpdate = "user_list_update"
)

type WebSocketMessage struct {
	Type    string `json:"Type"`
	Payload any    `json:"Payload"`
	Target  string `json:"Target,omitempty"`
	Sender  string `json:"Sender,omitempty"`
}

type UserListPayload struct {
	Users []models.User `json:"users"`
}

type Connection interface {
	SetWriteDeadline(time.Time) error
	WriteMessage(int, []byte) error
	Close() error
}

type userConnection struct {
	user       models.User
	connection Connection
	mu         sync.Mutex
}

type RoomManager struct {
	rooms map[string]map[string]*userConnection
	mu    sync.RWMutex
}

func NewRoomManager() *RoomManager {
	return &RoomManager{
		rooms: make(map[string]map[string]*userConnection),
	}
}

func (rm *RoomManager) AddUser(roomId string, user models.User, conn Connection) {
	rm.mu.Lock()

	uc := &userConnection{user: user, connection: conn}

	if _, ok := rm.rooms[roomId]; !ok {
		rm.rooms[roomId] = make(map[string]*userConnection)
		log.Printf("New room created: %s.", roomId)
	}

	rm.rooms[roomId][user.ConnectionId] = uc
	log.Printf("User %s (ID: %s) added to room %s.", user.Username, user.ConnectionId, roomId)

	rm.mu.Unlock()
	rm.broadcastUserList(roomId)
}

func (rm *RoomManager) RemoveUser(roomId string, userToRemove models.User) {
	rm.mu.Lock()

	room, ok := rm.rooms[roomId]
	if !ok {
		rm.mu.Unlock()
		log.Printf("Failed to remove user: Room %s not found.", roomId)
		return
	}

	uc, ok := room[userToRemove.ConnectionId]
	if !ok {
		rm.mu.Unlock()
		log.Printf("User with ID %s not found in room %s. Nothing to remove.", userToRemove.ConnectionId, roomId)
		return
	}

	// Close the underlying connection
	if err := uc.connection.Close(); err != nil {
		log.Printf("Failed to close connection for user %s: %v", uc.user.Username, err)
	}

	delete(room, userToRemove.ConnectionId)
	log.Printf("User %s (ID: %s) removed from room %s.", uc.user.Username, uc.user.ConnectionId, roomId)

	if len(room) == 0 {
		delete(rm.rooms, roomId)
		log.Printf("Room %s is now empty and deleted.", roomId)
		rm.mu.Unlock() // Unlock before returning
		return
	}

	rm.mu.Unlock()
	rm.broadcastUserList(roomId)
}

func (rm *RoomManager) RelayOrBroadcastMessage(roomId string, senderId string, message []byte) {
	var msg WebSocketMessage
	if err := json.Unmarshal(message, &msg); err != nil {
		log.Printf("Failed to unmarshal message in room %s: %v", roomId, err)
		// If unmarshal fails, fallback to simple broadcast for backward compatibility
		rm.broadcast(roomId, senderId, message)
		return
	}

	msg.Sender = senderId

	// Re-marshal message to include the sender ID
	updatedMessage, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Failed to marshal updated message in room %s: %v", roomId, err)
		return
	}

	if msg.Target != "" {
		// This is a targeted message for WebRTC signaling
		rm.sendToTarget(roomId, msg.Target, updatedMessage)
	} else {
		// This is a broadcast message for player state sync, etc.
		rm.broadcast(roomId, senderId, updatedMessage)
	}
}

func (rm *RoomManager) sendToTarget(roomId, targetId string, message []byte) {
	rm.mu.RLock()
	defer rm.mu.RUnlock()

	room, ok := rm.rooms[roomId]
	if !ok {
		return
	}

	if targetConn, ok := room[targetId]; ok {
		log.Printf("Relaying message to %s (ID: %s) in room %s", targetConn.user.Username, targetId, roomId)
		go rm.writeMessage(targetConn, message)
	} else {
		log.Printf("Target user with ID %s not found in room %s", targetId, roomId)
	}
}

func (rm *RoomManager) broadcast(roomId, senderId string, message []byte) {
	rm.mu.RLock()
	defer rm.mu.RUnlock()

	room, ok := rm.rooms[roomId]
	if !ok {
		return
	}

	for id, userConn := range room {
		if id == senderId {
			continue // Don't send message back to sender
		}
		log.Printf("Broadcasting message to %s in room %s", userConn.user.Username, roomId)
		go rm.writeMessage(userConn, message)
	}
}

func (rm *RoomManager) writeMessage(uc *userConnection, message []byte) {
	uc.mu.Lock()
	defer uc.mu.Unlock()

	err := uc.connection.SetWriteDeadline(time.Now().Add(config.WriteTimeout))
	if err != nil {
		log.Printf("Failed to set write deadline for user %s: %v", uc.user.Username, err)
		return
	}

	if err := uc.connection.WriteMessage(websocket.TextMessage, message); err != nil {
		log.Printf("Failed to write message to user %s: %v", uc.user.Username, err)
	}
}

func (rm *RoomManager) broadcastUserList(roomId string) {
	rm.mu.RLock()

	room, ok := rm.rooms[roomId]
	if !ok {
		rm.mu.RUnlock()
		log.Printf("Room %s not found for broadcasting user list.", roomId)
		return
	}

	var usersInRoom []models.User
	var userConnections []*userConnection
	for _, uc := range room {
		usersInRoom = append(usersInRoom, uc.user)
		userConnections = append(userConnections, uc)
	}

	rm.mu.RUnlock()

	msg := WebSocketMessage{
		Type:    MsgTypeUserListUpdate,
		Payload: UserListPayload{Users: usersInRoom},
	}

	bytes, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Failed to marshal user list for room %s: %v.", roomId, err)
		return
	}

	log.Printf("Broadcasting user list for room %s (Users: %v)", roomId, usersInRoom)
	for _, userConn := range userConnections {
		go rm.writeMessage(userConn, bytes)
	}
}
