package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // 允许所有来源，生产环境应更严格
	},
}

var connectionCount int64
var totalCPUUsage int64 // 以m为单位

func main() {
	http.HandleFunc("/ws", handleConnections)
	fmt.Println("服务器启动，监听端口 8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func handleConnections(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("升级到WebSocket失败:", err)
		return
	}
	defer conn.Close()

	atomic.AddInt64(&connectionCount, 1)
	defer func() {
		atomic.AddInt64(&connectionCount, -1)
		log.Printf("连接断开，当前连接数: %d, 总CPU使用量: %dm\n", atomic.LoadInt64(&connectionCount), atomic.LoadInt64(&totalCPUUsage))
	}()

	// 读取CPU百分比
	_, msg, err := conn.ReadMessage()
	if err != nil {
		log.Println("读取消息失败:", err)
		return
	}
	var cpuPercent float64
	fmt.Sscanf(string(msg), "%f", &cpuPercent)

	atomic.AddInt64(&totalCPUUsage, int64(cpuPercent*10)) // 百分比转换为m单位
	defer atomic.AddInt64(&totalCPUUsage, -int64(cpuPercent*10))

	log.Printf("新连接建立，CPU使用: %.2f%%, 当前连接数: %d, 总CPU使用量: %dm\n", cpuPercent, atomic.LoadInt64(&connectionCount), atomic.LoadInt64(&totalCPUUsage))

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	startTime := time.Now()

	// 启动goroutine处理CPU负载
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		consumeCPU(ctx, cpuPercent)
	}()

	// 偶尔发送状态
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		elapsed := time.Since(startTime)
		status := fmt.Sprintf("运行时间: %v, 连接数: %d, CPU使用量: %dm",
			elapsed, atomic.LoadInt64(&connectionCount), atomic.LoadInt64(&totalCPUUsage))
		err := conn.WriteMessage(websocket.TextMessage, []byte(status))
		if err != nil {
			log.Println("发送消息失败:", err)
			return
		}
	}
}

func consumeCPU(ctx context.Context, percent float64) {
	if percent <= 0 || percent > 100 {
		return
	}

	// 计算忙碌和空闲时间
	busyTime := time.Duration(percent*10) * time.Millisecond // 100ms周期
	idleTime := time.Duration((100-percent)*10) * time.Millisecond

	for {
		select {
		case <-ctx.Done():
			return
		default:
			start := time.Now()
			for time.Since(start) < busyTime {
				// 忙碌循环
			}
			time.Sleep(idleTime)
		}
	}
}
