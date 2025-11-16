# Makefile for the Go application

# Use bash as the shell for more advanced commands if needed.
SHELL := /bin/bash

# Set the name for the output binary.
BINARY_NAME=movie-backend

# Default command to run when 'make' is called without arguments.
.DEFAULT_GOAL := help

## ============================================================================
## Help
## ============================================================================

.PHONY: help
help:
	@echo "Usage: make <command>"
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%%-18s\033[0m %s\n", $$1, $$2}'

## ============================================================================
## Development
## ============================================================================

.PHONY: run
run: ## Run the application locally
	@echo "--> Running the application locally..."
	go run main.go

.PHONY: build
build: ## Build the application binary
	@echo "--> Building the application binary..."
	go build -o $(BINARY_NAME) main.go

.PHONY: test
test: ## Run all tests
	@echo "--> Running tests..."
	go test -v ./...

## ============================================================================
## Docker
## ============================================================================

.PHONY: docker-up
docker-up: ## Build and run the application with Docker Compose
	@echo "--> Starting application with Docker Compose..."
	docker-compose up --build

.PHONY: docker-down
docker-down: ## Stop and remove Docker containers
	@echo "--> Stopping Docker Compose application..."
	docker-compose down

.PHONY: docker-build
docker-build: ## Build the Docker image without running
	@echo "--> Building Docker image..."
	docker-compose build
