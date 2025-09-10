# 多阶段构建
# 第一阶段：构建Go应用
FROM golang:1.24-alpine AS builder

WORKDIR /app

# 复制go.mod和go.sum（如果有）
COPY go.mod go.sum ./

# 下载依赖
RUN go mod download

# 复制源代码
COPY . .

# 构建服务端
RUN go build -o server ./cmd/server

# 构建客户端
RUN go build -o client ./cmd/client

# 第二阶段：运行时镜像
FROM alpine:latest

# 安装ca-certificates（如果需要HTTPS）
RUN apk --no-cache add ca-certificates

WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/server .
COPY --from=builder /app/client .

# 暴露端口
EXPOSE 8080

