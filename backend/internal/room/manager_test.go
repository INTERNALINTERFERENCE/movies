package room

import (
	"backend/internal/models"
	"encoding/json"
	"sync"
	"testing"
	"time"
)

// mockConnection is a mock implementation of the Connection interface for testing.
type mockConnection struct {
	mu           sync.Mutex
	written      [][]byte
	isClosed     bool
	writeErr     error
	deadlineErr  error
	closeErr     error
	messageChan  chan []byte
	closeHandler func()
}

func newMockConnection() *mockConnection {
	return &mockConnection{
		written:     make([][]byte, 0),
		messageChan: make(chan []byte, 10), // Buffered channel
	}
}

func (m *mockConnection) WriteMessage(messageType int, data []byte) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.writeErr != nil {
		return m.writeErr
	}
	m.written = append(m.written, data)
	m.messageChan <- data // Send message to channel for inspection
	return nil
}

func (m *mockConnection) SetWriteDeadline(t time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.deadlineErr
}

func (m *mockConnection) Close() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.isClosed {
		return nil
	}
	m.isClosed = true
	if m.closeHandler != nil {
		m.closeHandler()
	}
	return m.closeErr
}

func (m *mockConnection) receivedMessage(t *testing.T, timeout time.Duration) ([]byte, bool) {
	t.Helper()
	select {
	case msg := <-m.messageChan:
		return msg, true
	case <-time.After(timeout):
		return nil, false
	}
}

func TestRoomManager_AddAndRemoveUser(t *testing.T) {
	rm := NewRoomManager()
	user := models.User{Username: "testuser", RoomId: "testroom", ConnectionId: "conn1"}
	conn := newMockConnection()

	t.Run("should add user to room", func(t *testing.T) {
		rm.AddUser(user.RoomId, user, conn)

		rm.mu.RLock()
		room, ok := rm.rooms[user.RoomId]
		if !ok {
			t.Fatalf("Room %s should have been created", user.RoomId)
		}
		if _, ok := room[user.ConnectionId]; !ok {
			t.Fatalf("User %s should be in the room", user.ConnectionId)
		}
		rm.mu.RUnlock()

		// Check if user list update was sent
		msgBytes, ok := conn.receivedMessage(t, 100*time.Millisecond)
		if !ok {
			t.Fatal("Expected a user list update message, but got none")
		}
		var msg WebSocketMessage
		if err := json.Unmarshal(msgBytes, &msg); err != nil {
			t.Fatalf("Failed to unmarshal message: %v", err)
		}
		if msg.Type != MsgTypeUserListUpdate {
			t.Errorf("Expected message type %s, but got %s", MsgTypeUserListUpdate, msg.Type)
		}
	})

	t.Run("should remove user from room", func(t *testing.T) {
		rm.RemoveUser(user.RoomId, user)

		rm.mu.RLock()
		defer rm.mu.RUnlock()

		if _, ok := rm.rooms[user.RoomId]; ok {
			t.Errorf("Room %s should have been deleted", user.RoomId)
		}
		if !conn.isClosed {
			t.Error("Expected connection to be closed, but it wasn't")
		}
	})
}

func TestRoomManager_RelayOrBroadcastMessage(t *testing.T) {
	rm := NewRoomManager()
	roomId := "webrtc-room"

	userA := models.User{Username: "userA", RoomId: roomId, ConnectionId: "connA"}
	connA := newMockConnection()
	rm.AddUser(roomId, userA, connA)
	// Drain the initial user list message for connA
	_, _ = connA.receivedMessage(t, 100*time.Millisecond)

	userB := models.User{Username: "userB", RoomId: roomId, ConnectionId: "connB"}
	connB := newMockConnection()
	rm.AddUser(roomId, userB, connB)
	// Drain the user list messages for both connections
	_, _ = connA.receivedMessage(t, 100*time.Millisecond)
	_, _ = connB.receivedMessage(t, 100*time.Millisecond)

	t.Run("should broadcast message to all other users", func(t *testing.T) {
		broadcastMsg := `{"type":"player_event", "payload":"play"}`
		rm.RelayOrBroadcastMessage(roomId, userA.ConnectionId, []byte(broadcastMsg))

		// Check that user B received the message
		msgBytes, ok := connB.receivedMessage(t, 100*time.Millisecond)
		if !ok {
			t.Fatal("User B should have received the broadcast message, but didn't")
		}
		var msg WebSocketMessage
		if err := json.Unmarshal(msgBytes, &msg); err != nil {
			t.Fatalf("Failed to unmarshal message: %v", err)
		}
		if msg.Sender != userA.ConnectionId {
			t.Errorf("Expected sender to be %s, but got %s", userA.ConnectionId, msg.Sender)
		}

		// Check that user A did NOT receive the message
		if _, ok := connA.receivedMessage(t, 50*time.Millisecond); ok {
			t.Error("User A should not have received their own broadcast message, but did")
		}
	})

	t.Run("should relay message to a specific target", func(t *testing.T) {
		relayMsg := `{"type":"webrtc-offer", "target":"connB"}`
		rm.RelayOrBroadcastMessage(roomId, userA.ConnectionId, []byte(relayMsg))

		// Check that user B received the message
		msgBytes, ok := connB.receivedMessage(t, 100*time.Millisecond)
		if !ok {
			t.Fatal("User B should have received the relay message, but didn't")
		}
		var msg WebSocketMessage
		if err := json.Unmarshal(msgBytes, &msg); err != nil {
			t.Fatalf("Failed to unmarshal message: %v", err)
		}
		if msg.Sender != userA.ConnectionId {
			t.Errorf("Expected sender to be %s, but got %s", userA.ConnectionId, msg.Sender)
		}
		if msg.Target != userB.ConnectionId {
			t.Errorf("Expected target to be %s, but got %s", userB.ConnectionId, msg.Target)
		}

		// Check that user A did NOT receive the message
		if _, ok := connA.receivedMessage(t, 50*time.Millisecond); ok {
			t.Error("User A should not have received their own relay message, but did")
		}
	})
}
