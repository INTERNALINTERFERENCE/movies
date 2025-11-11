package manager

import (
	"backend/internal/models"
	"encoding/json"
	"log"
	"sync"

	"github.com/gorilla/websocket"
)

const (
	MsgTypeUserListUpdate = "user_list_update"
)

type WebSocketMessage struct {
	Type    string `json:"type"`
	Payload any    `json:"payload"`
}

type UserListPayload struct {
	Usernames []string `json:"usernames"`
}

type userConnection struct {
	user       models.User
	connection *websocket.Conn
}

type RoomManager struct {
	rooms map[string]map[*userConnection]bool
	mu    sync.RWMutex
}

func NewRoomManager() *RoomManager {
	return &RoomManager{
		rooms: make(map[string]map[*userConnection]bool),
	}
}

func (rm *RoomManager) AddUser(roomId string, user models.User, conn *websocket.Conn) {
	rm.mu.Lock()

	uc := &userConnection{user, conn}

	if _, ok := rm.rooms[roomId]; !ok {
		rm.rooms[roomId] = make(map[*userConnection]bool)
		log.Printf("New room created: %s.", roomId)
	}

	rm.mu.Unlock()

	rm.rooms[roomId][uc] = true
	rm.broadcastUserList(roomId)
}

func (rm *RoomManager) RemoveUser(roomId string, connToRemove *websocket.Conn) {
	rm.mu.Lock()

	room, ok := rm.rooms[roomId]
	if !ok {
		log.Printf("Failed to remove user: Room %s not found.", roomId)
		return
	}

	var ucToRemove *userConnection

	for uc := range room {
		if uc.connection == connToRemove {
			ucToRemove = uc
			break
		}
	}

	if ucToRemove == nil {
		log.Printf("Connection not found in room %s. Nothing to remove.", roomId)
		return
	}

	delete(room, ucToRemove)
	log.Printf("User %s removed from room %s.", ucToRemove.user.Username, roomId)

	if len(room) == 0 {
		delete(rm.rooms, roomId)
		log.Printf("Room %s is now empty and deleted.", roomId)
		return
	}

	rm.mu.Unlock()
	rm.broadcastUserList(roomId)
}

func (rm *RoomManager) BroadcastMessage(roomId string, message []byte) {
	rm.mu.RLock()

	room, ok := rm.rooms[roomId]
	if !ok {
		rm.mu.RUnlock()
		return
	}

	connsToSend := make([]*websocket.Conn, 0, len(room))
	for uc := range room {
		connsToSend = append(connsToSend, uc.connection)
	}
	rm.mu.RUnlock()

	for _, conn := range connsToSend {
		go func() {
			if err := conn.WriteMessage(websocket.TextMessage, message); err != nil {
				log.Printf("Failed to broadcast message: %v", err)
			}
		}()
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

	usernames := make([]string, 0, len(room))
	conns := make([]*websocket.Conn, 0, len(room))
	for uc := range room {
		usernames = append(usernames, uc.user.Username)
		conns = append(conns, uc.connection)
	}

	rm.mu.RUnlock()

	msg := WebSocketMessage{
		MsgTypeUserListUpdate,
		UserListPayload{usernames},
	}

	bytes, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Failed to marshal user list for room %s: %v.", roomId, err)
		return
	}

	log.Printf("Broadcasting user list for room %s (Users: %v)", roomId, usernames)
	for _, conn := range conns {
		go func() {
			if err := conn.WriteMessage(websocket.TextMessage, bytes); err != nil {
				log.Printf("Failed to write user list for room %s: %v.", roomId, err)
			}
		}()
	}
}
