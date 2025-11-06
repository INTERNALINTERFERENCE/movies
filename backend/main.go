package main

import (
	"log"
	"net/http"

	"backend/internal/handler"
)

func main() {
	http.HandleFunc("/stream", handler.StreamHandler)
	log.Println("Starting WebSocket server on port 8080")
	log.Println("WebSocket endpoint: ws://localhost:8080/stream")

	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Fatalf("Fatal error starting server: %v", err)
	}
}
