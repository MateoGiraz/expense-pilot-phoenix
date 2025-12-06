FROM golang:1.22

# Set destination for COPY
WORKDIR /app

# Download Go modules
COPY . .
RUN go mod download

# Copy the source code. Note the slash at the end, as explained in
# https://docs.docker.com/reference/dockerfile/#copy
COPY *.go ./

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -o /expenses-service ./cmd/main.go

# Run
CMD ["/expenses-service"]