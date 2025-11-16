package config

import (
	"log"
	"os"
	"strconv"
	"time"
)

var (
	UserInitTimeout time.Duration
	WriteTimeout    time.Duration
)

func init() {
	UserInitTimeout = loadDurationFromEnv("USER_INIT_TIMEOUT_SECONDS", 10)
	WriteTimeout = loadDurationFromEnv("WRITE_TIMEOUT_SECONDS", 10)
}

func loadDurationFromEnv(key string, defaultValue int) time.Duration {
	valueStr := os.Getenv(key)
	if valueStr == "" {
		return time.Second * time.Duration(defaultValue)
	}

	value, err := strconv.Atoi(valueStr)
	if err != nil {
		log.Printf("Invalid value for %s: %s. Using default value: %d seconds", key, valueStr, defaultValue)
		return time.Second * time.Duration(defaultValue)
	}

	return time.Second * time.Duration(value)
}
