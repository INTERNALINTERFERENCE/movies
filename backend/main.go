package main

import (
	"log"
	"net/http"

	"backend/internal/handler"
	"backend/internal/room"

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	roomManager := room.NewRoomManager()
	wsHandler := handler.NewWebSocketHandler(roomManager)

	http.HandleFunc("/stream", wsHandler.StreamHandler)
	http.Handle("/metrics", promhttp.Handler())

	log.Println("Starting WebSocket server on port 8080")
	log.Println("WebSocket endpoint: ws://localhost:8080/stream")
	log.Println("Metrics endpoint: http://localhost:8080/metrics")

	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Fatalf("Fatal error starting server: %v", err)
	}
}
