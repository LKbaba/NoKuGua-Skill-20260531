# Dockerfile 优化模式详解

融合多个优秀技能的 Dockerfile 最佳实践。

## 基础镜像选择（2025 推荐）

### 推荐层级

```dockerfile
# 优先级 1: Wolfi/Chainguard（零 CVE 目标）
FROM cgr.dev/chainguard/node:latest

# 优先级 2: Alpine（通用最小化）
FROM node:20.11.0-alpine3.19

# 优先级 3: Distroless（无 shell，最安全）
FROM gcr.io/distroless/nodejs20-debian12

# 优先级 4: Slim（需要更多工具时）
FROM python:3.12-slim
```

### 版本标签规则

```dockerfile
# ✅ 正确：精确版本
FROM node:20.11.0-alpine3.19
FROM python:3.12.1-slim-bookworm

# ❌ 错误：模糊版本
FROM node:latest
FROM python:3
```

---

## 层缓存优化

### 正确的指令顺序

```dockerfile
# 1. 基础镜像和系统依赖（很少变化）
FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# 2. 应用依赖（偶尔变化）
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 3. 应用代码（频繁变化）
COPY . /app
WORKDIR /app

# 4. 运行时配置
ENV PYTHONUNBUFFERED=1
EXPOSE 8000
CMD ["python", "app.py"]
```

### 合并 RUN 命令

```dockerfile
# ✅ 好：单层，清理有效
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# ❌ 差：多层，缓存未清理导致镜像膨胀
RUN apt-get update
RUN apt-get install -y curl
RUN rm -rf /var/lib/apt/lists/*
```

---

## BuildKit 缓存挂载（2025 推荐）

### npm 缓存

```dockerfile
# syntax=docker/dockerfile:1.4
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --only=production
```

### pip 缓存

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

### apt 缓存

```dockerfile
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y curl
```

---

## 多阶段构建完整示例

### Node.js/TypeScript

```dockerfile
# ============================================
# 阶段 1: 依赖安装
# ============================================
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --only=production

# ============================================
# 阶段 2: 构建
# ============================================
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# ============================================
# 阶段 3: 运行时（最小镜像）
# ============================================
FROM node:20-alpine AS runtime

# 安全：创建非 root 用户
RUN addgroup -g 1001 -S nodejs && \
    adduser -S appuser -u 1001 -G nodejs

WORKDIR /app

# 只复制必要文件
COPY --from=deps --chown=appuser:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:nodejs /app/dist ./dist
COPY --from=builder --chown=appuser:nodejs /app/package*.json ./

USER 1001
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["node", "dist/index.js"]
```

### Python/FastAPI

```dockerfile
# 构建阶段
FROM python:3.12-slim AS builder
WORKDIR /app

# 安装构建依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 创建虚拟环境
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 安装依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 运行阶段
FROM python:3.12-slim AS runtime
WORKDIR /app

# 创建非 root 用户
RUN groupadd -g 1001 appgroup && \
    useradd -m -u 1001 -g appgroup appuser

# 复制虚拟环境
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 复制应用
COPY --chown=appuser:appgroup . .

USER 1001
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Go（最小镜像）

```dockerfile
# 构建阶段
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o server

# 运行阶段（scratch = 空镜像，约 10MB）
FROM scratch
COPY --from=builder /app/server /server
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
EXPOSE 8080
ENTRYPOINT ["/server"]
```

---

## .dockerignore 最佳实践

```dockerignore
# 版本控制
.git
.gitignore

# 依赖目录
node_modules
__pycache__
.venv
vendor

# 构建输出
dist
build
*.egg-info
.next

# 开发文件
*.md
!README.md
*.log
.env*
!.env.example

# IDE
.vscode
.idea
*.swp

# 测试
tests
coverage
.pytest_cache
playwright-report

# Docker 相关
Dockerfile*
docker-compose*
.dockerignore
```

---

## 信号处理和优雅关闭

### CMD 形式对比

```dockerfile
# ✅ exec 形式：正确接收信号
CMD ["node", "server.js"]

# ❌ shell 形式：信号被 /bin/sh 拦截
CMD node server.js
```

### Node.js 优雅关闭

```javascript
// 在应用中处理 SIGTERM
process.on('SIGTERM', () => {
  console.log('收到 SIGTERM，正在关闭...');
  server.close(() => {
    console.log('服务器已关闭');
    process.exit(0);
  });
});
```

---

## 多架构构建

```bash
# 创建 buildx 构建器
docker buildx create --name multiarch --use

# 构建并推送多架构镜像
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myapp:latest \
  --push .
```
