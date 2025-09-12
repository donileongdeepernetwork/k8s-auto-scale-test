# 测试用例说明
每个pod实例可以限制资源为1000m CPU，即1个CPU。自动扩容配置为1分钟的所有pod的平均CPU使用高于50%，则增加pod。在5分钟所有pod平均CPU使用低于25%则减少pod数量。

client会发送websocket请求，服务端用一个空循环模拟CPU消耗，每个客户端连接会让服务端约产生200m，即20%的1个CPU负载。用4个客户端，目的让k8s自动增加1个pod，随后停掉旧的客户端后再启动8个客户端，测试k8s是否会再增加1个pod来应对负载。

# 测试前状态

现在是1个pod，自动扩容策略显示当前只需要1个pod。

```bash
=== Pods ===
kubectl get pods -n k8s-auto-scale-test -l app=k8s-auto-scale-test
NAME                                   READY   STATUS    RESTARTS   AGE
k8s-auto-scale-test-54454676cf-rw5sr   1/1     Running   0          49s
=== Services ===
kubectl get svc -n k8s-auto-scale-test
NAME                          TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)          AGE
k8s-auto-scale-test-service   LoadBalancer   10.245.28.113   137.184.249.241   8080:32337/TCP   52s
=== HPA ===
kubectl get hpa -n k8s-auto-scale-test
NAME                      REFERENCE                        TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
k8s-auto-scale-test-hpa   Deployment/k8s-auto-scale-test   cpu: 1%/50%   1         10        1          50s
=== Deployments ===
kubectl get deployments -n k8s-auto-scale-test
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
k8s-auto-scale-test   1/1     1            1           52s
=== Top ===
kubectl top pods -n k8s-auto-scale-test
NAME                                   CPU(cores)   MEMORY(bytes)
k8s-auto-scale-test-54454676cf-rw5sr   1m           1Mi
```

# 1分钟后

所有pod（目前只有1个）平均负载为62%，已经达到扩容配置的50%，预计1分钟后会增加pod。

```bash
=== Pods ===
kubectl get pods -n k8s-auto-scale-test -l app=k8s-auto-scale-test
NAME                                   READY   STATUS    RESTARTS   AGE
k8s-auto-scale-test-5b95d988b5-hcl8r   1/1     Running   0          12m
=== Services ===
kubectl get svc -n k8s-auto-scale-test
NAME                          TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)          AGE
k8s-auto-scale-test-service   LoadBalancer   10.245.28.113   137.184.249.241   8080:32337/TCP   15m
=== HPA ===
kubectl get hpa -n k8s-auto-scale-test
NAME                      REFERENCE                        TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
k8s-auto-scale-test-hpa   Deployment/k8s-auto-scale-test   cpu: 62%/50%   1         10        1          15m
=== Deployments ===
kubectl get deployments -n k8s-auto-scale-test
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
k8s-auto-scale-test   1/1     1            1           15m
=== Top ===
kubectl top pods -n k8s-auto-scale-test
NAME                                   CPU(cores)   MEMORY(bytes)
k8s-auto-scale-test-5b95d988b5-hcl8r   628m         2Mi
```

# 2分钟后
k8s开始增加pod来应对现在的负载。但是因为k8s当前的节点不足以创建新的pod，所以需要增加节点。

```bash
=== Pods ===
kubectl get pods -n k8s-auto-scale-test -l app=k8s-auto-scale-test
NAME                                   READY   STATUS    RESTARTS   AGE
k8s-auto-scale-test-5b95d988b5-56g4l   0/1     Pending   0          37s
k8s-auto-scale-test-5b95d988b5-hcl8r   1/1     Running   0          14m
=== Services ===
kubectl get svc -n k8s-auto-scale-test
NAME                          TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)          AGE
k8s-auto-scale-test-service   LoadBalancer   10.245.28.113   137.184.249.241   8080:32337/TCP   17m
=== HPA ===
kubectl get hpa -n k8s-auto-scale-test
NAME                      REFERENCE                        TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
k8s-auto-scale-test-hpa   Deployment/k8s-auto-scale-test   cpu: 67%/50%   1         10        2          17m
=== Deployments ===
kubectl get deployments -n k8s-auto-scale-test
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
k8s-auto-scale-test   1/2     2            1           17m
=== Top ===
kubectl top pods -n k8s-auto-scale-test
NAME                                   CPU(cores)   MEMORY(bytes)
k8s-auto-scale-test-5b95d988b5-hcl8r   672m         2Mi
```

# 约5分钟后
新的k8s节点自动创建完成，心的pod也成功启动了，这时候平均负载时33%，降下来了。但是因为4个客户端都是跟旧的pod保持连接，所以旧的pod负载没有降下来。

下一步，我会停止4个客户端，然后启动8个客户端产生更多的负载。
```bash
=== Pods ===
kubectl get pods -n k8s-auto-scale-test -l app=k8s-auto-scale-test
NAME                                   READY   STATUS    RESTARTS   AGE
k8s-auto-scale-test-5b95d988b5-56g4l   1/1     Running   0          3m33s
k8s-auto-scale-test-5b95d988b5-hcl8r   1/1     Running   0          16m
=== Services ===
kubectl get svc -n k8s-auto-scale-test
NAME                          TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)          AGE
k8s-auto-scale-test-service   LoadBalancer   10.245.28.113   137.184.249.241   8080:32337/TCP   20m
=== HPA ===
kubectl get hpa -n k8s-auto-scale-test
NAME                      REFERENCE                        TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
k8s-auto-scale-test-hpa   Deployment/k8s-auto-scale-test   cpu: 70%/50%   1         10        2          20m
=== Deployments ===
kubectl get deployments -n k8s-auto-scale-test
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
k8s-auto-scale-test   2/2     2            2           20m
=== Top ===
kubectl top pods -n k8s-auto-scale-test
NAME                                   CPU(cores)   MEMORY(bytes)
k8s-auto-scale-test-5b95d988b5-56g4l   2m           2Mi
k8s-auto-scale-test-5b95d988b5-hcl8r   709m         2Mi
```

# 约8分钟后
可以看到8个客户端的负载反应到两个pod里面了，现在平均负载时59%了。

```bash
=== Pods ===
kubectl get pods -n k8s-auto-scale-test -l app=k8s-auto-scale-test
NAME                                   READY   STATUS    RESTARTS   AGE
k8s-auto-scale-test-5b95d988b5-56g4l   1/1     Running   0          6m35s
k8s-auto-scale-test-5b95d988b5-hcl8r   1/1     Running   0          20m
=== Services ===
kubectl get svc -n k8s-auto-scale-test
NAME                          TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)          AGE
k8s-auto-scale-test-service   LoadBalancer   10.245.28.113   137.184.249.241   8080:32337/TCP   23m
=== HPA ===
kubectl get hpa -n k8s-auto-scale-test
NAME                      REFERENCE                        TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
k8s-auto-scale-test-hpa   Deployment/k8s-auto-scale-test   cpu: 59%/50%   1         10        2          23m
=== Deployments ===
kubectl get deployments -n k8s-auto-scale-test
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
k8s-auto-scale-test   2/2     2            2           23m
=== Top ===
kubectl top pods -n k8s-auto-scale-test
NAME                                   CPU(cores)   MEMORY(bytes)
k8s-auto-scale-test-5b95d988b5-56g4l   593m         2Mi
k8s-auto-scale-test-5b95d988b5-hcl8r   591m         2Mi
```

# 约9分钟后
可以看到，因为k8s已经有足够节点运行新的pod，所以无需等待新的k8s节点，而是直接创建了一个新的pod。

```bash
=== Pods ===
kubectl get pods -n k8s-auto-scale-test -l app=k8s-auto-scale-test
NAME                                   READY   STATUS    RESTARTS   AGE
k8s-auto-scale-test-5b95d988b5-56g4l   1/1     Running   0          7m17s
k8s-auto-scale-test-5b95d988b5-hcl8r   1/1     Running   0          20m
k8s-auto-scale-test-5b95d988b5-kl46x   1/1     Running   0          17s
=== Services ===
kubectl get svc -n k8s-auto-scale-test
NAME                          TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)          AGE
k8s-auto-scale-test-service   LoadBalancer   10.245.28.113   137.184.249.241   8080:32337/TCP   23m
=== HPA ===
kubectl get hpa -n k8s-auto-scale-test
NAME                      REFERENCE                        TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
k8s-auto-scale-test-hpa   Deployment/k8s-auto-scale-test   cpu: 76%/50%   1         10        3          23m
=== Deployments ===
kubectl get deployments -n k8s-auto-scale-test
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
k8s-auto-scale-test   3/3     3            3           23m
=== Top ===
kubectl top pods -n k8s-auto-scale-test
NAME                                   CPU(cores)   MEMORY(bytes)
k8s-auto-scale-test-5b95d988b5-56g4l   599m         2Mi
k8s-auto-scale-test-5b95d988b5-hcl8r   924m         3Mi
```
# 约10分钟后
关闭掉所有客户端，开始测试缩容，预计在5分钟后k8s的pod会缩减至1个。

```bash
=== Pods ===
kubectl get pods -n k8s-auto-scale-test -l app=k8s-auto-scale-test
NAME                                   READY   STATUS    RESTARTS   AGE
k8s-auto-scale-test-5b95d988b5-56g4l   1/1     Running   0          8m21s
k8s-auto-scale-test-5b95d988b5-hcl8r   1/1     Running   0          21m
k8s-auto-scale-test-5b95d988b5-kl46x   1/1     Running   0          81s
=== Services ===
kubectl get svc -n k8s-auto-scale-test
NAME                          TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)          AGE
k8s-auto-scale-test-service   LoadBalancer   10.245.28.113   137.184.249.241   8080:32337/TCP   24m
=== HPA ===
kubectl get hpa -n k8s-auto-scale-test
NAME                      REFERENCE                        TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
k8s-auto-scale-test-hpa   Deployment/k8s-auto-scale-test   cpu: 54%/50%   1         10        3          24m
=== Deployments ===
kubectl get deployments -n k8s-auto-scale-test
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
k8s-auto-scale-test   3/3     3            3           24m
=== Top ===
kubectl top pods -n k8s-auto-scale-test
NAME                                   CPU(cores)   MEMORY(bytes)
k8s-auto-scale-test-5b95d988b5-56g4l   670m         3Mi
k8s-auto-scale-test-5b95d988b5-hcl8r   949m         3Mi
k8s-auto-scale-test-5b95d988b5-kl46x   1m           2Mi
```

# 约12分钟后

当前平均负载为0%。

```bash
=== Pods ===
kubectl get pods -n k8s-auto-scale-test -l app=k8s-auto-scale-test
NAME                                   READY   STATUS    RESTARTS   AGE
k8s-auto-scale-test-5b95d988b5-56g4l   1/1     Running   0          9m54s
k8s-auto-scale-test-5b95d988b5-hcl8r   1/1     Running   0          23m
k8s-auto-scale-test-5b95d988b5-kl46x   1/1     Running   0          2m54s
=== Services ===
kubectl get svc -n k8s-auto-scale-test
NAME                          TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)          AGE
k8s-auto-scale-test-service   LoadBalancer   10.245.28.113   137.184.249.241   8080:32337/TCP   26m
=== HPA ===
kubectl get hpa -n k8s-auto-scale-test
NAME                      REFERENCE                        TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
k8s-auto-scale-test-hpa   Deployment/k8s-auto-scale-test   cpu: 0%/50%   1         10        3          26m
=== Deployments ===
kubectl get deployments -n k8s-auto-scale-test
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
k8s-auto-scale-test   3/3     3            3           26m
=== Top ===
kubectl top pods -n k8s-auto-scale-test
NAME                                   CPU(cores)   MEMORY(bytes)
k8s-auto-scale-test-5b95d988b5-56g4l   1m           3Mi
k8s-auto-scale-test-5b95d988b5-hcl8r   1m           3Mi
k8s-auto-scale-test-5b95d988b5-kl46x   1m           2Mi
```
# 约16分钟后
新建的两个pod被陆续回收了。测试完成。
```bash
=== Pods ===
kubectl get pods -n k8s-auto-scale-test -l app=k8s-auto-scale-test
NAME                                   READY   STATUS    RESTARTS   AGE
k8s-auto-scale-test-5b95d988b5-hcl8r   1/1     Running   0          27m
=== Services ===
kubectl get svc -n k8s-auto-scale-test
NAME                          TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)          AGE
k8s-auto-scale-test-service   LoadBalancer   10.245.28.113   137.184.249.241   8080:32337/TCP   30m
=== HPA ===
kubectl get hpa -n k8s-auto-scale-test
NAME                      REFERENCE                        TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
k8s-auto-scale-test-hpa   Deployment/k8s-auto-scale-test   cpu: 0%/50%   1         10        1          30m
=== Deployments ===
kubectl get deployments -n k8s-auto-scale-test
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
k8s-auto-scale-test   1/1     1            1           30m
=== Top ===
kubectl top pods -n k8s-auto-scale-test
NAME                                   CPU(cores)   MEMORY(bytes)
k8s-auto-scale-test-5b95d988b5-hcl8r   1m           4Mi

```
