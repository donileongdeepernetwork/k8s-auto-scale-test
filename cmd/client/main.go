package main

import (
	"flag"
	"fmt"
	"log"
	"net/url"
	"os"
	"os/signal"

	"github.com/gorilla/websocket"
)

func main() {
	ip := flag.String("ip", "127.0.0.1", "服务器IP")
	port := flag.String("port", "8080", "服务器端口")
	cpu := flag.Float64("cpu", 10.0, "CPU使用百分比")
	flag.Parse()

	u := url.URL{Scheme: "ws", Host: *ip + ":" + *port, Path: "/ws"}
	log.Printf("连接到 %s", u.String())

	conn, _, err := websocket.DefaultDialer.Dial(u.String(), nil)
	if err != nil {
		log.Fatal("连接失败:", err)
	}
	defer conn.Close()

	// 发送CPU百分比
	err = conn.WriteMessage(websocket.TextMessage, []byte(fmt.Sprintf("%.2f", *cpu)))
	if err != nil {
		log.Fatal("发送消息失败:", err)
	}

	// 处理中断信号
	interrupt := make(chan os.Signal, 1)
	signal.Notify(interrupt, os.Interrupt)

	done := make(chan struct{})

	go func() {
		defer close(done)
		for {
			_, message, err := conn.ReadMessage()
			if err != nil {
				log.Println("读取消息失败:", err)
				return
			}
			log.Printf("收到: %s", message)
		}
	}()

	for {
		select {
		case <-done:
			return
		case <-interrupt:
			log.Println("中断")
			err := conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""))
			if err != nil {
				log.Println("关闭连接失败:", err)
			}
			return
		}
	}
}
