IMAGE_NAME = k8s-auto-scale-test
CONTAINER_NAME = k8s-auto-scale-test-container
NAMESPACE = k8s-auto-scale-test
NUM_CLIENTS ?= 3
CPU_PERCENT ?= 20
CLIENT_IP ?= 127.0.0.1

.DEFAULT_GOAL := help
.PHONY: build run test clean deploy undeploy status forward logs load-test restart help

# 构建Docker镜像
build:
	docker build -t $(IMAGE_NAME) .

# 运行容器（前台）
run: build
	docker run -p 8080:8080 --name $(CONTAINER_NAME) --rm $(IMAGE_NAME)

# 测试容器（后台运行，检查端口）
test: build
	@echo "启动容器进行测试..."
	docker run -d -p 8080:8080 --name $(CONTAINER_NAME) $(IMAGE_NAME)
	@echo "等待5秒让服务启动..."
	sleep 5
	@echo "检查端口8080是否开放..."
	nc -z localhost 8080 && echo "端口8080开放，服务运行正常" || echo "端口8080未开放，服务可能有问题"
	@echo "查看容器日志..."
	docker logs $(CONTAINER_NAME)
	@echo "停止容器..."
	docker stop $(CONTAINER_NAME) || true
	docker rm $(CONTAINER_NAME) || true

# 清理容器和镜像
clean:
	docker stop $(CONTAINER_NAME) || true
	docker rm $(CONTAINER_NAME) || true
	docker rmi $(IMAGE_NAME) || true

# 部署Kubernetes资源
deploy:
	kubectl apply -k k8s/

# 删除Kubernetes资源
undeploy:
	kubectl delete -k k8s/

# 重启Kubernetes Deployment
restart:
	@echo "重启Deployment..."
	kubectl rollout restart deployment/k8s-auto-scale-test -n $(NAMESPACE)
	@echo "等待Pod重启..."
	kubectl rollout status deployment/k8s-auto-scale-test -n $(NAMESPACE)

# 查看Kubernetes资源状态
status:
	@echo "=== Pods ==="
	kubectl get pods -n $(NAMESPACE) -l app=k8s-auto-scale-test
	@echo "=== Services ==="
	kubectl get svc -n $(NAMESPACE)
	@echo "=== HPA ==="
	kubectl get hpa -n $(NAMESPACE)
	@echo "=== Deployments ==="
	kubectl get deployments -n $(NAMESPACE)
	@echo "=== Top ==="
	kubectl top pods -n $(NAMESPACE)

# 端口转发到本地
forward:
	@echo "将远程service端口8080转发到本地8080..."
	kubectl port-forward -n $(NAMESPACE) svc/k8s-auto-scale-test-service 8080:8080

# 查看Kubernetes Pod日志
logs:
	@echo "查看Pod日志（最后50行，并跟随）..."
	kubectl logs -n $(NAMESPACE) -l app=k8s-auto-scale-test --tail=50 -f

# 启动多个客户端进行负载测试
load-test:
	@echo "=== 负载测试配置 ==="
	@echo "可配置参数 (使用 make load-test PARAM=value 进行修改):"
	@echo "  NUM_CLIENTS: 客户端数量 (当前: $(NUM_CLIENTS))"
	@echo "  CPU_PERCENT: 每个客户端的CPU使用百分比 (当前: $(CPU_PERCENT))"
	@echo "  CLIENT_IP: 服务器IP地址 (当前: $(CLIENT_IP))"
	@echo ""
	@echo "启动 $(NUM_CLIENTS) 个客户端，连接到 $(CLIENT_IP):8080，每个使用 $(CPU_PERCENT)% CPU..."
	@echo "按 Ctrl+C 停止所有客户端"
	@trap 'echo ""; echo "停止所有客户端..."; pkill -f "go run cmd/client"; exit' INT; \
	for i in $$(seq 1 $(NUM_CLIENTS)); do \
		echo "启动客户端 $$i..."; \
		go run cmd/client/main.go -ip $(CLIENT_IP) -port 8080 -cpu $(CPU_PERCENT) & \
	done; \
	wait

# 显示帮助信息
help:
	@echo "可用目标:"
	@echo "  build       - 构建Docker镜像"
	@echo "  run         - 运行容器（前台）"
	@echo "  test        - 构建并测试容器（后台运行，检查端口和日志）"
	@echo "  clean       - 停止并删除容器和镜像"
	@echo "  deploy      - 部署Kubernetes资源"
	@echo "  undeploy    - 删除Kubernetes资源"
	@echo "  status      - 查看Kubernetes资源状态"
	@echo "  forward     - 将远程service端口转发到本地"
	@echo "  logs        - 查看Kubernetes Pod日志"
	@echo "  load-test   - 启动多个客户端进行负载测试 (NUM_CLIENTS=3, CPU_PERCENT=20, CLIENT_IP=127.0.0.1)"
	@echo "  restart     - 重启Kubernetes Deployment"
	@echo "  help        - 显示此帮助信息"
