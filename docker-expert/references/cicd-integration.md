# CI/CD 集成指南

Docker 与 GitHub Actions、GitLab CI 的集成最佳实践。

## GitHub Actions

### 完整构建和推送流程

```yaml
# .github/workflows/docker.yml
name: 构建并推送 Docker 镜像

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: 检出代码
        uses: actions/checkout@v4

      - name: 设置 Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: 登录容器仓库
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: 提取 Docker 元数据
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha

      - name: 构建并推送
        uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: 安全扫描
        if: github.event_name != 'pull_request'
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: 上传扫描结果
        if: github.event_name != 'pull_request'
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
```

### 多平台构建

```yaml
- name: 设置 QEMU（多平台支持）
  uses: docker/setup-qemu-action@v3

- name: 构建多平台镜像
  uses: docker/build-push-action@v5
  with:
    context: .
    platforms: linux/amd64,linux/arm64
    push: true
    tags: ${{ steps.meta.outputs.tags }}
```

### 测试后再推送

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: 构建测试镜像
        run: docker build -t myapp:test --target test .
      - name: 运行测试
        run: docker run --rm myapp:test npm test

  build:
    needs: test  # 测试通过后才构建
    runs-on: ubuntu-latest
    steps:
      - name: 构建生产镜像
        uses: docker/build-push-action@v5
        with:
          context: .
          target: production
          push: true
```

---

## GitLab CI

### 完整流水线

```yaml
# .gitlab-ci.yml
stages:
  - build
  - test
  - security
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
  IMAGE_LATEST: $CI_REGISTRY_IMAGE:latest

# 构建镜像
build:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $IMAGE_TAG .
    - docker push $IMAGE_TAG
  rules:
    - if: $CI_COMMIT_BRANCH

# 运行测试
test:
  stage: test
  image: docker:24
  services:
    - docker:24-dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker pull $IMAGE_TAG
    - docker run --rm $IMAGE_TAG npm test
  rules:
    - if: $CI_COMMIT_BRANCH

# 安全扫描
security_scan:
  stage: security
  image:
    name: aquasec/trivy:latest
    entrypoint: [""]
  script:
    - trivy image --exit-code 1 --severity CRITICAL $IMAGE_TAG
  allow_failure: true
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

# 部署到生产
deploy_production:
  stage: deploy
  image: docker:24
  services:
    - docker:24-dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker pull $IMAGE_TAG
    - docker tag $IMAGE_TAG $IMAGE_LATEST
    - docker push $IMAGE_LATEST
    # 部署命令（根据实际情况修改）
    - echo "部署到生产环境..."
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  when: manual
```

---

## 镜像标签策略

### 语义化版本

```bash
# 版本标签
myapp:1.2.3
myapp:1.2
myapp:1

# 环境标签
myapp:1.2.3-production
myapp:1.2.3-staging

# Git SHA（便于追踪）
myapp:1.2.3-abc123f
```

### GitHub Actions 自动标签

```yaml
- name: 提取元数据
  uses: docker/metadata-action@v5
  with:
    images: ghcr.io/${{ github.repository }}
    tags: |
      # 分支名（如 main）
      type=ref,event=branch
      # 语义版本（v1.2.3 → 1.2.3, 1.2, 1）
      type=semver,pattern={{version}}
      type=semver,pattern={{major}}.{{minor}}
      type=semver,pattern={{major}}
      # Git SHA
      type=sha,prefix=
      # PR 编号
      type=ref,event=pr
```

---

## 缓存优化

### GitHub Actions 缓存

```yaml
- name: 构建并推送
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: ${{ steps.meta.outputs.tags }}
    # 使用 GitHub Actions 缓存
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### 注册表缓存（更快）

```yaml
- name: 构建并推送
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: ${{ steps.meta.outputs.tags }}
    # 使用注册表作为缓存
    cache-from: type=registry,ref=${{ env.IMAGE_NAME }}:buildcache
    cache-to: type=registry,ref=${{ env.IMAGE_NAME }}:buildcache,mode=max
```

---

## 多阶段构建目标

### Dockerfile 设计

```dockerfile
# 基础阶段
FROM node:20-alpine AS base
WORKDIR /app
COPY package*.json ./

# 开发阶段
FROM base AS development
RUN npm install
COPY . .
CMD ["npm", "run", "dev"]

# 测试阶段
FROM base AS test
RUN npm ci
COPY . .
CMD ["npm", "test"]

# 构建阶段
FROM base AS build
RUN npm ci
COPY . .
RUN npm run build

# 生产阶段
FROM base AS production
RUN npm ci --only=production
COPY --from=build /app/dist ./dist
USER node
CMD ["node", "dist/server.js"]
```

### CI 中使用不同目标

```yaml
# 测试阶段
- name: 构建测试镜像
  run: docker build --target test -t myapp:test .
- name: 运行测试
  run: docker run --rm myapp:test

# 生产阶段
- name: 构建生产镜像
  uses: docker/build-push-action@v5
  with:
    target: production
    push: true
```

---

## 安全扫描集成

### Trivy 扫描

```yaml
- name: Trivy 漏洞扫描
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'myapp:${{ github.sha }}'
    format: 'table'
    exit-code: '1'
    ignore-unfixed: true
    vuln-type: 'os,library'
    severity: 'CRITICAL,HIGH'
```

### Docker Scout 扫描

```yaml
- name: Docker Scout 分析
  uses: docker/scout-action@v1
  with:
    command: cves
    image: 'myapp:${{ github.sha }}'
    sarif-file: scout-results.sarif
```

---

## 部署策略

### 蓝绿部署

```yaml
deploy:
  script:
    # 启动新版本（绿色）
    - docker-compose -f docker-compose.prod.yml up -d --no-deps app-green
    # 等待健康检查通过
    - sleep 30
    - curl -f http://app-green:3000/health || exit 1
    # 切换流量
    - docker-compose exec nginx nginx -s reload
    # 停止旧版本（蓝色）
    - docker-compose stop app-blue
```

### 滚动更新

```yaml
deploy:
  script:
    - docker-compose -f docker-compose.prod.yml pull app
    - docker-compose -f docker-compose.prod.yml up -d --no-deps app
```
