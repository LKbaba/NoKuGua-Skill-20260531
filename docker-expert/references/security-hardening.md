# 容器安全加固指南

Docker 容器安全最佳实践，含 BuildKit Secrets 和运行时安全。

## 非 Root 用户配置

### 创建专用用户

```dockerfile
# Alpine Linux
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Debian/Ubuntu
RUN groupadd -g 1001 appgroup && \
    useradd -m -u 1001 -g appgroup appuser

# 设置文件所有权
COPY --chown=appuser:appgroup . .

# 切换用户（推荐使用数字 UID）
USER 1001
```

### 为什么使用数字 UID/GID？

```dockerfile
# ✅ 推荐：使用数字，明确且可预测
USER 1001

# ⚠️ 可接受：使用用户名
USER appuser

# ❌ 绝对不要：使用 root
USER root
```

---

## Secrets 管理

### ❌ 错误做法（Secrets 会保存在镜像层）

```dockerfile
# 危险：secrets 会永久保存在镜像层历史中
ENV API_KEY=example-api-key-placeholder
COPY .env /app/.env
RUN echo "password" > /app/config
```

### ✅ 正确做法

#### 方法 1: BuildKit Secrets（构建时）

```dockerfile
# syntax=docker/dockerfile:1.4
FROM alpine

# Secret 只在这个 RUN 命令中可用，不会保存到层中
RUN --mount=type=secret,id=api_key \
    API_KEY=$(cat /run/secrets/api_key) && \
    ./configure --api-key=$API_KEY
```

构建命令：
```bash
docker build --secret id=api_key,src=./api_key.txt .
```

#### 方法 2: Docker Secrets（Swarm/Compose）

```yaml
# docker-compose.yml
services:
  app:
    secrets:
      - db_password
      - api_key
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_key:
    external: true
```

应用代码读取：
```python
def get_secret(name):
    """从文件或环境变量读取 secret"""
    try:
        with open(f'/run/secrets/{name}') as f:
            return f.read().strip()
    except FileNotFoundError:
        return os.environ.get(name.upper())
```

#### 方法 3: 运行时环境变量

```bash
# 从文件加载（不提交到 Git）
docker run --env-file .env.production myapp

# 单个变量
docker run -e API_KEY="$API_KEY" myapp
```

---

## 最小攻击面

### 只安装必要包

```dockerfile
# ✅ 好：使用 --no-install-recommends 和清理
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# ❌ 差：安装不必要的包
RUN apt-get update && apt-get install -y curl vim wget git
```

### 使用虚拟包并移除构建依赖

```dockerfile
# Alpine：使用虚拟包
RUN apk add --no-cache --virtual .build-deps \
        gcc musl-dev && \
    pip install -r requirements.txt && \
    apk del .build-deps
```

---

## 运行时安全

### Docker run 安全参数

```bash
docker run \
  # 以非 root 用户运行
  --user 1001:1001 \
  # 删除所有能力，只添加必要的
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  # 只读根文件系统
  --read-only \
  # 临时可写目录
  --tmpfs /tmp:noexec,nosuid \
  # 禁止获取新权限
  --security-opt="no-new-privileges:true" \
  # 资源限制
  --memory="512m" \
  --cpus="1.0" \
  my-image
```

### Compose 安全配置

```yaml
services:
  app:
    # 只读文件系统
    read_only: true
    tmpfs:
      - /tmp
      - /var/run
    # 能力限制
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    # 安全选项
    security_opt:
      - no-new-privileges:true
    # 资源限制
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
```

---

## 镜像安全扫描

### Docker Scout

```bash
# 快速查看
docker scout quickview myapp:latest

# 详细 CVE 报告
docker scout cves myapp:latest

# 修复建议
docker scout recommendations myapp:latest
```

### Trivy（开源）

```bash
# 扫描本地镜像
trivy image myapp:latest

# 只显示高危和严重漏洞
trivy image --severity HIGH,CRITICAL myapp:latest

# 扫描 Dockerfile
trivy config Dockerfile
```

### CI/CD 集成

```yaml
# GitHub Actions
- name: 安全扫描
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'myapp:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'
```

---

## 网络隔离

```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # 关键：禁止外部访问

services:
  web:
    networks:
      - frontend

  api:
    networks:
      - frontend
      - backend

  database:
    networks:
      - backend  # 数据库完全隔离，无外部访问
```

---

## CIS Docker Benchmark 要点

### 主机配置
- [ ] 使用独立分区存储 Docker 数据
- [ ] 审计 Docker 守护进程活动
- [ ] 配置适当的日志级别

### Docker 守护进程配置
- [ ] 启用用户命名空间重映射
- [ ] 使用 TLS 进行远程 API 访问
- [ ] 配置 ulimit 默认值

### 容器镜像
- [ ] 不在镜像中存储 secrets
- [ ] 使用 COPY 而非 ADD
- [ ] 不使用 root 用户

### 容器运行时
- [ ] 不使用 --privileged
- [ ] 不挂载 Docker socket
- [ ] 设置适当的重启策略
- [ ] 限制容器资源

---

## 安全检查清单

### 镜像安全
- [ ] 使用官方、最小化的基础镜像
- [ ] 指定精确版本标签（非 latest）
- [ ] 容器以非 root 用户运行（USER 指令）
- [ ] 使用特定 UID/GID（1001:1001）
- [ ] Secrets 不在 ENV 或镜像层中
- [ ] 定期运行漏洞扫描
- [ ] 基础镜像保持更新

### 构建安全
- [ ] 使用 BuildKit secrets 处理构建时凭证
- [ ] 只安装必要的包
- [ ] 构建工具不在生产镜像中
- [ ] 使用多阶段构建

### 运行时安全
- [ ] 删除不必要的 Linux capabilities（cap-drop=ALL）
- [ ] 使用只读文件系统（read-only）
- [ ] 启用 no-new-privileges
- [ ] 设置资源限制（CPU、内存）
- [ ] 网络隔离（内部网络）

### 合规
- [ ] 遵循 CIS Docker Benchmark
- [ ] CI/CD 中集成容器扫描
- [ ] 使用签名镜像（Docker Content Trust）
- [ ] 保留审计日志

---

## 常见安全反模式

```dockerfile
# ❌ 永远不要这样做
RUN --privileged                    # 给予所有权限
RUN -v /var/run/docker.sock         # 暴露 Docker socket
ENV PASSWORD=secret123              # 在层中存储 secret
USER root                           # 以 root 运行
EXPOSE 22                           # 暴露 SSH
```
