# Stage 1: Build environment
FROM golang:1.20-alpine AS builder
WORKDIR /app
COPY main.go .
RUN go build -o server main.go

# Stage 2: Runtime environment
FROM alpine:latest
WORKDIR /app
# Copy only the compiled binary from the builder stage
COPY --from=builder /app/server .
EXPOSE 8080
CMD ["./server"]