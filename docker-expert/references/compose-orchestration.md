# Docker Compose 编排模式

生产级 Docker Compose 配置模式和最佳实践，含 Monorepo 和本地服务栈。

## 服务依赖管理

### 健康检查依赖

```yaml
services:
  app:
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy

  db:
    image: postgres:15-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
```

---

## 网络配置

### 前后端网络隔离

```yaml
services:
  nginx:
    networks:
      - frontend
    ports:
      - "80:80"

  app:
    networks:
      - frontend
      - backend

  db:
    networks:
      - backend  # 数据库只在内部网络，无外部访问

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # 关键：禁止外部访问
```

---

## 资源限制

### CPU 和内存限制

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 120s
```

### 日志轮转

```yaml
services:
  app:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

---

## 多环境配置

### 文件结构

```
project/
├── docker-compose.yml          # 基础配置
├── docker-compose.override.yml # 开发覆盖（自动加载）
├── docker-compose.prod.yml     # 生产覆盖
├── docker-compose.test.yml     # 测试配置
└── .env                        # 环境变量
```

### 基础配置 (docker-compose.yml)

```yaml
services:
  app:
    build:
      context: .
    environment:
      - NODE_ENV=${NODE_ENV:-production}
    networks:
      - app-network

networks:
  app-network:
```

### 开发覆盖 (docker-compose.override.yml)

```yaml
# 自动与 docker-compose.yml 合并
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
    volumes:
      - .:/app
      - /app/node_modules  # 排除 node_modules
    environment:
      - NODE_ENV=development
      - DEBUG=app:*
    ports:
      - "9229:9229"  # 调试端口
    command: npm run dev

  db:
    ports:
      - "5432:5432"  # 暴露给本地工具
```

### 生产覆盖 (docker-compose.prod.yml)

```yaml
services:
  app:
    build:
      context: .
      target: runtime
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### 启动命令

```bash
# 开发环境（自动加载 override）
docker-compose up

# 生产环境
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## Monorepo 多服务模式

```yaml
services:
  # 前端
  web:
    build:
      context: .
      dockerfile: apps/web/Dockerfile
    ports:
      - "3000:3000"
    environment:
      - API_URL=http://api:4000
    depends_on:
      - api
    networks:
      - frontend
      - backend

  # 后端 API
  api:
    build:
      context: .
      dockerfile: apps/api/Dockerfile
    ports:
      - "4000:4000"
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/myapp
      - REDIS_URL=redis://redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    networks:
      - backend

  # 后台 Worker
  worker:
    build:
      context: .
      dockerfile: apps/worker/Dockerfile
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/myapp
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
    deploy:
      replicas: 2
    networks:
      - backend

  # 数据库
  db:
    image: postgres:15-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend

  # 缓存
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - backend

networks:
  frontend:
  backend:

volumes:
  postgres_data:
  redis_data:
```

---

## 本地服务栈

### 常用开发服务

```yaml
# docker-compose.services.yml
services:
  # 本地 S3 兼容存储
  minio:
    image: minio/minio
    ports:
      - "9000:9000"
      - "9001:9001"  # 控制台
    volumes:
      - minio_data:/data
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    command: server /data --console-address ":9001"

  # 本地邮件测试
  mailhog:
    image: mailhog/mailhog
    ports:
      - "1025:1025"  # SMTP
      - "8025:8025"  # Web UI

  # Elasticsearch
  elasticsearch:
    image: elasticsearch:8.11.0
    ports:
      - "9200:9200"
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data

  # Kibana
  kibana:
    image: kibana:8.11.0
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    depends_on:
      - elasticsearch

volumes:
  minio_data:
  elasticsearch_data:
```

---

## 测试配置

```yaml
# docker-compose.test.yml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.test
    environment:
      - NODE_ENV=test
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/myapp_test
    depends_on:
      db:
        condition: service_healthy
    command: npm run test:ci

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp_test
    tmpfs:
      - /var/lib/postgresql/data  # 使用 tmpfs 加速测试
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
      interval: 2s
      timeout: 5s
      retries: 5

  # E2E 测试
  playwright:
    image: mcr.microsoft.com/playwright:v1.40.0-focal
    volumes:
      - .:/app
      - /app/node_modules
    working_dir: /app
    environment:
      - CI=true
      - BASE_URL=http://app:3000
    depends_on:
      - app
    command: npx playwright test
```

---

## Secrets 管理

### 文件 Secrets

```yaml
services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

### 外部 Secrets（Swarm 模式）

```yaml
secrets:
  db_password:
    external: true  # 使用 docker secret create 创建
```

---

## 健康检查代码示例

### TypeScript/Express

```typescript
// src/routes/health.ts
import { Router } from 'express';

const router = Router();

router.get('/health', async (req, res) => {
  const checks = {
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    database: false,
    redis: false,
  };

  try {
    await db.query('SELECT 1');
    checks.database = true;
  } catch (e) {
    console.error('数据库健康检查失败:', e);
  }

  try {
    await redis.ping();
    checks.redis = true;
  } catch (e) {
    console.error('Redis 健康检查失败:', e);
  }

  const isHealthy = checks.database && checks.redis;
  res.status(isHealthy ? 200 : 503).json(checks);
});

export default router;
```

---

## 常用命令

```bash
# 开发
docker-compose up -d              # 后台启动
docker-compose logs -f app        # 跟踪日志
docker-compose exec app sh        # 进入容器
docker-compose up -d --build      # 重新构建

# 生产
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
docker-compose up -d --scale app=3  # 扩容

# 清理
docker-compose down               # 停止并移除容器
docker-compose down -v            # 同时移除卷
```
