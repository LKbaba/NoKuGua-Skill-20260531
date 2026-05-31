# Docker 故障排除指南

常见 Docker 问题的诊断和解决方案，含平台特定指南。

## 构建问题

### 构建缓慢（10+ 分钟）

**症状：** 每次构建都要很长时间，依赖频繁重新下载

**诊断：**
```bash
# 查看构建历史和层大小
docker history <image> --no-trunc

# 检查构建上下文大小
du -sh .
du -sh ./* | sort -h | tail -20

# 检查 .dockerignore
cat .dockerignore
```

**解决方案：**
1. 优化层顺序（依赖先复制）
```dockerfile
COPY package*.json ./
RUN npm ci
COPY . .
```

2. 使用 BuildKit 缓存挂载
```dockerfile
RUN --mount=type=cache,target=/root/.npm npm ci
```

3. 完善 .dockerignore
```dockerignore
node_modules
.git
dist
*.log
```

### "Build context too large"

**解决方案：**
```bash
# 检查上下文大小
du -sh .

# 创建 .dockerignore
cat > .dockerignore << 'EOF'
node_modules/
.git/
*.log
dist/
coverage/
EOF
```

---

## 镜像问题

### 镜像过大（1GB+）

**诊断：**
```bash
# 查看镜像大小
docker images | grep <image>

# 分析层大小
docker history <image>

# 使用 dive 深入分析
dive <image>
```

**解决方案：**

1. 使用多阶段构建
```dockerfile
FROM node:20 AS build
# 构建...

FROM node:20-alpine AS runtime
# 只复制必要文件
```

2. 使用更小的基础镜像
```dockerfile
# 从 ~1GB → ~180MB
FROM node:20-alpine
# 或 ~20MB
FROM gcr.io/distroless/nodejs20
```

3. 清理构建缓存（同一层）
```dockerfile
RUN npm ci && npm cache clean --force
RUN apt-get install -y curl && rm -rf /var/lib/apt/lists/*
```

### 安全漏洞（CVE）

**诊断：**
```bash
# Docker Scout
docker scout cves <image>

# Trivy
trivy image <image>
trivy image --severity HIGH,CRITICAL <image>
```

**解决方案：**
1. 更新基础镜像版本
2. 使用 Wolfi/Chainguard 镜像
3. 定期重建镜像

---

## 容器运行时问题

### 容器立即退出

**诊断：**
```bash
# 查看日志
docker logs <container>

# 检查退出码
docker inspect -f '{{.State.ExitCode}}' <container>

# 交互式调试
docker run -it --entrypoint /bin/sh <image>
```

**常见原因和解决方案：**

| 退出码 | 含义 | 解决方案 |
|-------|-----|---------|
| 0 | 正常退出 | 检查 CMD 是否前台运行 |
| 1 | 应用错误 | 检查日志，修复代码 |
| 137 | OOM Killed | 增加内存限制 |
| 139 | 段错误 | 检查二进制兼容性 |

**CMD 形式检查：**
```dockerfile
# ✅ 正确：前台运行
CMD ["node", "server.js"]

# ❌ 错误：后台运行会导致容器退出
CMD ["node", "server.js", "&"]
```

### 权限拒绝

**诊断：**
```bash
# 以 root 进入容器调试
docker exec -u root -it <container> sh

# 检查文件权限
ls -la /app
```

**解决方案：**
```dockerfile
# 在 Dockerfile 中修复所有权
COPY --chown=appuser:appgroup . .

# 或在运行时
docker exec -u root <container> chown -R appuser:appgroup /app
```

### 健康检查失败

**诊断：**
```bash
# 查看容器状态
docker ps -a

# 查看健康检查历史
docker inspect <container> | grep -A 20 Health

# 手动测试健康检查
docker exec <container> curl -f http://localhost:3000/health
```

**解决方案：**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 60s  # 增加启动等待时间
```

---

## 网络问题

### 服务间无法通信

**诊断：**
```bash
# 检查网络
docker network ls
docker network inspect <network>

# 检查容器网络
docker inspect <container> | grep -A 20 Networks

# 容器内测试
docker exec <container> ping <service-name>
docker exec <container> nslookup <service-name>
```

**解决方案：**
1. 确保服务在同一网络
```yaml
services:
  app:
    networks:
      - app-network
  db:
    networks:
      - app-network

networks:
  app-network:
```

2. 使用服务名作为主机名
```yaml
environment:
  DB_HOST: db  # 使用服务名，不是 localhost 或 IP
```

### "Port already in use"

**诊断：**
```bash
# 查找占用端口的进程
# Linux/macOS
lsof -i :3000
netstat -tulpn | grep 3000

# Windows
netstat -ano | findstr :3000
```

**解决方案：**
```bash
# 杀死进程
kill -9 <PID>

# 或使用不同端口
docker run -p 3001:3000 myapp
```

### "Cannot connect to Docker daemon"

**诊断：**
```bash
docker info
```

**解决方案：**
```bash
# Linux
sudo systemctl restart docker
sudo usermod -aG docker $USER
# 重新登录

# Windows/macOS
# 重启 Docker Desktop
```

---

## 存储问题

### "No space left on device"

**诊断：**
```bash
docker system df
df -h
```

**解决方案：**
```bash
# 清理未使用的资源
docker system prune -a --volumes

# 分别清理
docker container prune    # 停止的容器
docker image prune -a     # 未使用的镜像
docker volume prune       # 未使用的卷
docker builder prune      # 构建缓存
```

---

## 平台特定问题

### Windows

**卷挂载路径格式：**
```yaml
# ✅ 正确
volumes:
  - C:/Users/name/app:/app
  - //c/Users/name/app:/app  # Git Bash 格式

# ❌ 错误
volumes:
  - C:\Users\name\app:/app  # 需要转义
```

**行尾符问题：**
```dockerfile
# 确保脚本使用 LF 而非 CRLF
RUN sed -i 's/\r$//' /app/entrypoint.sh
```

**WSL2 后端性能优化：**
- 将项目放在 WSL 文件系统中（/home/user/）
- 而非 Windows 挂载（/mnt/c/）

### macOS

**卷挂载性能优化：**
```yaml
volumes:
  - ./src:/app/src:delegated  # 主机写入延迟，性能更好
  - ./build:/app/build:cached  # 容器写入缓存
```

**M1/M2 (ARM) 兼容性：**
```bash
# 指定平台
docker build --platform linux/amd64 -t myapp .

# 或在 Dockerfile 中
FROM --platform=linux/amd64 node:20-alpine
```

### Linux

**权限问题（bind mount）：**
```bash
# 使用与容器相同的 UID/GID 运行
docker run -u $(id -u):$(id -g) -v $(pwd):/app myapp
```

**用户命名空间重映射：**
```json
// /etc/docker/daemon.json
{
  "userns-remap": "default"
}
```

---

## 调试命令速查

```bash
# 容器状态
docker ps -a                          # 所有容器
docker stats                          # 资源使用
docker top <container>                # 进程列表

# 日志
docker logs <container>               # 完整日志
docker logs -f --tail 100 <container> # 最后 100 行并跟踪

# 进入容器
docker exec -it <container> sh        # Shell
docker exec -it <container> bash      # Bash（如果有）

# 检查配置
docker inspect <container>            # 完整配置
docker inspect -f '{{.State.Status}}' <container>  # 状态
docker inspect -f '{{.NetworkSettings.IPAddress}}' <container>  # IP

# 网络
docker network ls                     # 列出网络
docker network inspect <network>      # 网络详情

# Compose
docker-compose config                 # 验证配置
docker-compose logs -f                # 日志
docker-compose ps                     # 服务状态
```

---

## 问题诊断流程图

```
容器不工作
    │
    ├── 构建失败？
    │       │
    │       ├── 检查 Dockerfile 语法
    │       ├── 检查 .dockerignore
    │       └── 查看构建日志
    │
    ├── 启动失败？
    │       │
    │       ├── docker logs <container>
    │       ├── 检查 CMD/ENTRYPOINT
    │       └── 检查依赖服务
    │
    ├── 运行时错误？
    │       │
    │       ├── docker exec -it <container> sh
    │       ├── 检查环境变量
    │       └── 检查文件权限
    │
    └── 网络问题？
            │
            ├── docker network inspect
            ├── 检查服务名
            └── 检查端口映射
```
