package main

import (
	"log"
	"net/http"

	"backend/internal/handler"
)

func main() {
	http.HandleFunc("/pingpong", handler.PingPongHandler)
	log.Println("[Server] Starting WebSocket server on port 8080")
	log.Println("[Server] WebSocket endpoint: ws://localhost:8080/pingpong")

	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Fatalf("[Server] Fatal error starting server: %v", err)
	}
}
