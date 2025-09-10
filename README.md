# k8s-auto-scale-test

[![Build and Push Docker Image](https://github.com/donileongdeepernetwork/k8s-auto-scale-test/actions/workflows/docker-build-push.yml/badge.svg)](https://github.com/donileongdeepernetwork/k8s-auto-scale-test/actions/workflows/docker-build-push.yml)

这是一个用于测试Kubernetes自动扩展功能的Go项目。

## 项目概述

本项目旨在测试Kubernetes的自动扩展（Auto Scaling）功能。通过模拟CPU密集型负载，观察HPA（Horizontal Pod Autoscaler）如何根据CPU使用率动态调整Pod数量。

## 架构

- **服务器 (cmd/server/main.go)**: 提供WebSocket服务，接收客户端连接，执行CPU密集型运算以模拟负载。
- **客户端 (cmd/client/main.go)**: 连接到服务器，指定CPU使用百分比，接收并打印服务器的回复信息。

## 功能需求

### 服务器端

- 提供WebSocket服务，监听指定端口。
- 接收客户端连接，获取CPU使用百分比参数（针对1个CPU核心）。
- 执行运算以恒定使用指定的CPU百分比。
- 偶尔回复服务器运行时间和当前状态（例如连接数、CPU使用量）。
- 记录当前连接的客户端数量。
- 记录当前使用的CPU总量（以m单位，Kubernetes资源单位）。

### 客户端

- 接受命令行参数：服务器IP、端口、CPU使用百分比。
- 连接到服务器的WebSocket。
- 接收服务器的回复信息。
- 打印接收到的信息到控制台。

## 使用方法

1. **启动服务器**:
   ```
   go run cmd/server/main.go
   ```

2. **启动客户端**:
   ```
   go run cmd/client/main.go -ip <server_ip> -port <port> -cpu <percentage>
   ```
   例如：
   ```
   go run cmd/client/main.go -ip 127.0.0.1 -port 8080 -cpu 50
   ```

## 依赖

- Go 1.19+
- WebSocket库：`github.com/gorilla/websocket`

## 部署到Kubernetes

- 使用Deployment部署服务器Pod。
- 配置HPA根据CPU使用率自动扩展Pod数量。
- 客户端可以作为Job或单独的Pod运行，用于生成负载。

## 构建和运行

1. 初始化Go模块：
   ```
   go mod init k8s-auto-scale-test
   ```

2. 安装依赖：
   ```
   go mod tidy
   ```

3. 构建：
   ```
   go build ./cmd/server
   go build ./cmd/client
   ```

## Docker构建和运行

1. **构建Docker镜像**:
   ```
   docker build -t k8s-auto-scale-test .
   ```

2. **运行容器**:
   ```
   docker run -p 8080:8080 k8s-auto-scale-test
   ```

   容器启动后，会自动启动服务器并连接一个客户端（使用50% CPU）。

3. **从GitHub Container Registry拉取镜像**:
   ```
   docker pull ghcr.io/donileongdeepernetwork/k8s-auto-scale-test:latest
   docker run -p 8080:8080 ghcr.io/donileongdeepernetwork/k8s-auto-scale-test:latest
   ```

   注意：需要先登录GitHub Container Registry（如果镜像为私有）：
   ```
   echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
   ```

## 注意事项

- 确保Kubernetes集群中配置了Metrics Server以支持HPA。
- CPU使用百分比是针对单个CPU核心的模拟负载。
- 服务器会记录连接数和总CPU使用量，便于监控和调试。
