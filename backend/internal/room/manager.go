package manager

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
	Type    string `json:"type"`
	Payload any    `json:"payload"`
}

type UserListPayload struct {
	Usernames []string `json:"usernames"`
}

type userConnection struct {
	user       models.User
	connection *websocket.Conn
	mu         sync.Mutex
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

	uc := &userConnection{user: user, connection: conn}

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

	usersToSend := make([]*userConnection, 0, len(room))
	for uc := range room {
		usersToSend = append(usersToSend, uc)
	}
	rm.mu.RUnlock()

	for _, userConn := range usersToSend {
		go func(uc *userConnection) {
			uc.mu.Lock()
			defer uc.mu.Unlock()

			log.Printf("Attempting to broadcast message to user %s in room %s", uc.user.Username, roomId)
			err := uc.connection.SetWriteDeadline(time.Now().Add(config.WriteTimeout))
			if err != nil {
				log.Printf("Failed to set write deadline for user %s: %v", uc.user.Username, err)
				return
			}

			if err := uc.connection.WriteMessage(websocket.TextMessage, message); err != nil {
				log.Printf("Failed to broadcast message to user %s: %v", uc.user.Username, err)
			} else {
				log.Printf("Successfully broadcasted message to user %s in room %s.", uc.user.Username, roomId)
			}
		}(userConn)
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
	usersToUpdate := make([]*userConnection, 0, len(room))
	for uc := range room {
		usernames = append(usernames, uc.user.Username)
		usersToUpdate = append(usersToUpdate, uc)
	}

	rm.mu.RUnlock()

	msg := WebSocketMessage{
		Type:    MsgTypeUserListUpdate,
		Payload: UserListPayload{Usernames: usernames},
	}

	bytes, err := json.Marshal(msg)
	if err != nil {
		log.Printf("Failed to marshal user list for room %s: %v.", roomId, err)
		return
	}

	log.Printf("Broadcasting user list for room %s (Users: %v)", roomId, usernames)
	for _, userConn := range usersToUpdate {
		go func(uc *userConnection) {
			uc.mu.Lock()
			defer uc.mu.Unlock()

			err := uc.connection.SetWriteDeadline(time.Now().Add(config.WriteTimeout))
			if err != nil {
				log.Printf("Failed to set write deadline for user %s: %v", uc.user.Username, err)
				return
			}

			if err := uc.connection.WriteMessage(websocket.TextMessage, bytes); err != nil {
				log.Printf("Failed to write user list for room %s to user %s: %v.", roomId, uc.user.Username, err)
			}
		}(userConn)
	}
}
