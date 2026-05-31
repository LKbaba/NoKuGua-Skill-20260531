#!/bin/bash
# Docker 安全清理脚本
# 用法: bash docker-cleanup.sh [--aggressive]
# --aggressive: 清理所有未使用资源（包括未使用的镜像）

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印带颜色的标题
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 显示当前磁盘使用
show_disk_usage() {
    print_header "当前 Docker 磁盘使用"
    docker system df
}

# 清理已停止的容器
cleanup_containers() {
    print_header "清理已停止容器"

    local count=$(docker ps -a --filter "status=exited" -q | wc -l)
    if [[ $count -eq 0 ]]; then
        print_ok "没有已停止的容器需要清理"
        return
    fi

    print_info "发现 $count 个已停止容器"

    # 列出将被清理的容器
    echo "将清理以下容器:"
    docker ps -a --filter "status=exited" --format "  - {{.Names}} ({{.Image}}, 退出于 {{.Status}})"

    # 执行清理
    docker container prune -f
    print_ok "已清理 $count 个容器"
}

# 清理悬空镜像
cleanup_dangling_images() {
    print_header "清理悬空镜像"

    local count=$(docker images -f "dangling=true" -q | wc -l)
    if [[ $count -eq 0 ]]; then
        print_ok "没有悬空镜像需要清理"
        return
    fi

    print_info "发现 $count 个悬空镜像"
    docker image prune -f
    print_ok "已清理 $count 个悬空镜像"
}

# 清理未使用的镜像（激进模式）
cleanup_unused_images() {
    print_header "清理未使用镜像"

    print_warn "这将清理所有未被任何容器使用的镜像"

    # 显示将被清理的镜像
    local unused=$(docker images -q | wc -l)
    local used=$(docker ps -a --format '{{.Image}}' | sort -u | wc -l)
    local to_remove=$((unused - used))

    if [[ $to_remove -le 0 ]]; then
        print_ok "没有未使用的镜像需要清理"
        return
    fi

    print_info "约 $to_remove 个镜像将被清理"
    docker image prune -a -f
    print_ok "已清理未使用镜像"
}

# 清理未使用的卷
cleanup_volumes() {
    print_header "清理未使用卷"

    local count=$(docker volume ls -qf "dangling=true" | wc -l)
    if [[ $count -eq 0 ]]; then
        print_ok "没有未使用的卷需要清理"
        return
    fi

    print_warn "发现 $count 个未使用卷"
    print_warn "卷可能包含重要数据，清理前请确认"

    # 列出将被清理的卷
    echo "将清理以下卷:"
    docker volume ls -qf "dangling=true" | while read vol; do
        echo "  - $vol"
    done

    docker volume prune -f
    print_ok "已清理 $count 个卷"
}

# 清理未使用的网络
cleanup_networks() {
    print_header "清理未使用网络"

    # 获取自定义网络数量（排除默认网络）
    local count=$(docker network ls --filter "type=custom" -q | wc -l)
    local used=$(docker network ls --filter "dangling=false" --filter "type=custom" -q | wc -l)

    docker network prune -f
    print_ok "已清理未使用网络"
}

# 清理构建缓存
cleanup_build_cache() {
    print_header "清理构建缓存"

    # 检查 BuildKit 缓存
    local cache_size=$(docker system df --format '{{.Size}}' | tail -1)
    print_info "当前构建缓存大小: $cache_size"

    docker builder prune -f
    print_ok "已清理构建缓存"
}

# 显示清理结果
show_result() {
    print_header "清理完成"

    echo "清理后磁盘使用:"
    docker system df

    echo -e "\n${GREEN}清理完成！${NC}"
}

# 确认提示
confirm_cleanup() {
    local mode=$1

    echo -e "${YELLOW}"
    echo "========================================"
    echo "       Docker 清理工具 v1.0            "
    echo "========================================"
    echo -e "${NC}"

    if [[ "$mode" == "--aggressive" ]]; then
        print_warn "激进模式: 将清理所有未使用资源"
    else
        print_info "安全模式: 只清理悬空资源"
    fi

    show_disk_usage

    echo ""
    read -p "是否继续清理? [y/N] " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "取消清理"
        exit 0
    fi
}

# 安全清理（默认）
safe_cleanup() {
    cleanup_containers
    cleanup_dangling_images
    cleanup_networks
    cleanup_build_cache
}

# 激进清理
aggressive_cleanup() {
    cleanup_containers
    cleanup_dangling_images
    cleanup_unused_images
    cleanup_volumes
    cleanup_networks
    cleanup_build_cache
}

# 主函数
main() {
    # 检查 Docker 是否运行
    if ! docker info &> /dev/null; then
        echo -e "${RED}[ERROR]${NC} Docker 守护进程未运行"
        exit 1
    fi

    local mode="${1:-safe}"

    # 非交互模式检测
    if [[ "$2" == "-y" || "$2" == "--yes" ]]; then
        # 跳过确认
        :
    else
        confirm_cleanup "$mode"
    fi

    # 执行清理
    if [[ "$mode" == "--aggressive" ]]; then
        aggressive_cleanup
    else
        safe_cleanup
    fi

    show_result
}

main "$@"
