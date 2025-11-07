package models

type User struct {
	ConnectionId string `json:"connectionId"`
	Username     string `json:"username"`
	RoomId       string `json:"roomId"`
}
