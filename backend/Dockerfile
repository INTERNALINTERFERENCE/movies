# --- 1. Build Stage ---
# Use the official Go image as a build environment.
# Using alpine for a smaller build image.
FROM golang:1.21-alpine AS builder

# Set the working directory inside the container.
WORKDIR /app

# Copy go.mod and go.sum files to download dependencies first.
# This leverages Docker's layer caching to avoid re-downloading dependencies
# on every code change.
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source code into the container.
COPY . .

# Build the Go application.
# CGO_ENABLED=0 is important for creating a static binary that can run in a minimal image.
# -o /server specifies the output file name.
RUN CGO_ENABLED=0 go build -o /server ./main.go


# --- 2. Final Stage ---
# Use a minimal, empty base image.
FROM scratch

# Copy the compiled binary from the build stage.
COPY --from=builder /server /server

# Expose port 8080 to the outside world.
EXPOSE 8080

# Set the command to run when the container starts.
CMD ["/server"]
