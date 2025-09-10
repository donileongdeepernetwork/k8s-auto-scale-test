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
- 偶尔回复服务器运行时间、当前状态和Pod名称（例如连接数、CPU使用量、Pod名称）。
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
   或设置监听地址：
   ```
   LISTEN_ADDR=0.0.0.0:9090 go run cmd/server/main.go
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

3. **使用Makefile**:
   ```
   # 构建镜像
   make build

   # 运行容器
   make run

   # 测试容器（自动检查端口和日志）
   make test

   # 清理容器和镜像
   make clean

   # 显示帮助
   make help
   ```

4. **从GitHub Container Registry拉取镜像**:
   ```
   docker pull ghcr.io/donileongdeepernetwork/k8s-auto-scale-test:latest
   docker run -p 8080:8080 ghcr.io/donileongdeepernetwork/k8s-auto-scale-test:latest
   ```

   注意：需要先登录GitHub Container Registry（如果镜像为私有）：
   ```
   echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
   ```

## Kubernetes部署

项目包含Kustomization配置用于在Kubernetes中部署自动扩展的服务端。

### 前提条件

- Kubernetes集群（1.19+）
- Metrics Server已安装（用于HPA）
- kubectl已配置

### 部署步骤

1. **应用Kustomization配置**:
   ```
   kubectl apply -k k8s/
   ```
   或使用Makefile:
   ```
   make deploy
   ```

   注意：这将自动创建 `k8s-auto-scale-test` namespace并在其中部署3个Pod副本，实现负载均衡。

2. **检查部署状态**:
   ```
   kubectl get pods -n k8s-auto-scale-test -l app=k8s-auto-scale-test
   kubectl get hpa -n k8s-auto-scale-test k8s-auto-scale-test-hpa
   ```
   或使用Makefile:
   ```
   make status
   ```

3. **查看服务**:
   ```
   kubectl get svc -n k8s-auto-scale-test k8s-auto-scale-test-service
   ```

4. **监控自动扩展**:
   ```
   kubectl get hpa -n k8s-auto-scale-test k8s-auto-scale-test-hpa -w
   ```

5. **端口转发到本地**:
   ```
   kubectl port-forward -n k8s-auto-scale-test svc/k8s-auto-scale-test-service 8080:8080
   ```
   或使用Makefile:
   ```
   make forward
   ```

   这将允许你在本地通过 `http://localhost:8080` 访问Kubernetes中的服务。

6. **查看Pod日志**:
   ```
   kubectl logs -n k8s-auto-scale-test -l app=k8s-auto-scale-test --tail=50 -f
   ```
   或使用Makefile:
   ```
   make logs
   ```

   这将显示Pod的实时日志输出。

7. **启动负载测试客户端**:
   ```
   make load-test NUM_CLIENTS=5 CPU_PERCENT=30 CLIENT_IP=127.0.0.1
   ```
   或使用默认值:
   ```
   make load-test
   ```

   这将启动多个客户端连接到指定IP的8080端口进行负载测试。默认启动3个客户端，连接127.0.0.1，每个使用20% CPU。测试将在前台运行，按 Ctrl+C 可以同时停止所有客户端。

   **可配置参数**:
   - `NUM_CLIENTS`: 客户端数量 (默认: 3)
   - `CPU_PERCENT`: 每个客户端的CPU使用百分比 (默认: 20)
   - `CLIENT_IP`: 服务器IP地址 (默认: 127.0.0.1)

   示例:
   ```
   make load-test NUM_CLIENTS=10 CPU_PERCENT=50 CLIENT_IP=192.168.1.100
   ```

### 使用方法

### HPA配置说明

- **目标CPU利用率**: 50%
- **最小副本数**: 3
- **最大副本数**: 10
- **扩展行为**:
  - 扩容：CPU > 50% 时，每60秒最多增加100%的副本
  - 缩容：CPU < 50% 时，每60秒最多减少50%的副本，稳定窗口300秒

### 自定义配置

- 修改 `k8s/kustomization.yaml` 中的镜像标签
- 调整 `k8s/hpa.yaml` 中的扩展参数
- 修改 `k8s/deployment.yaml` 中的资源限制

### 清理

```
kubectl delete -k k8s/
```
或使用Makefile:
```
make undeploy
```

## 注意事项

- 确保Kubernetes集群中配置了Metrics Server以支持HPA。
- CPU使用百分比是针对单个CPU核心的模拟负载。
- 服务器会记录连接数和总CPU使用量，便于监控和调试。
