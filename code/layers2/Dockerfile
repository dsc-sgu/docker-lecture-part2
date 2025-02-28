FROM golang:1.23-alpine as builder

WORKDIR /app
COPY go.mod go.sum .
RUN go mod download

COPY . .
RUN go build -o ./main main.go

FROM alpine:3.20
COPY --from=builder /app/main /app/main

ENTRYPOINT [ "/app/main" ]
