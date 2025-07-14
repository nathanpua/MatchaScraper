# Stage 1: Build the Go application
FROM golang:1.24.5-alpine AS builder

# Set the Current Working Directory inside the container
WORKDIR /app

# Copy go mod and sum files from the app directory
COPY app/go.mod app/go.sum ./

# Download all dependencies. Dependencies will be cached if the go.mod and go.sum files are not changed
RUN go mod download

# Copy the source code from the app directory
COPY app/ .

# Build the Go app
# -ldflags="-w -s" reduces the size of the binary by removing debug information
# CGO_ENABLED=0 is required for a static build
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /main .

# Stage 2: Create the final, lightweight image
FROM alpine:latest

# It's good practice to run as a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copy the Pre-built binary file from the previous stage
COPY --from=builder /main /main

# Copy CA certificates - needed for making HTTPS requests to websites and Telegram
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Command to run the executable
CMD ["sh", "-c", "echo '--- Environment Variables ---' && printenv && echo '--- Starting Application ---' && /main"] 