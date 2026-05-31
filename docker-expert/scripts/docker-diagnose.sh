#!/bin/bash
# Docker 一键诊断脚本
# 用法: bash docker-diagnose.sh [容器名/ID]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 打印带颜色的标题
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# 打印成功信息
print_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# 打印警告信息
print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 打印错误信息
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Docker 是否安装和运行
check_docker() {
    print_header "Docker 环境检测"

    # 检查 Docker 命令
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装"
        exit 1
    fi
    print_ok "Docker 已安装: $(docker --version)"

    # 检查 Docker 守护进程
    if ! docker info &> /dev/null; then
        print_error "Docker 守护进程未运行"
        echo "  解决方案: "
        echo "  - Linux: sudo systemctl start docker"
        echo "  - Windows/macOS: 启动 Docker Desktop"
        exit 1
    fi
    print_ok "Docker 守护进程运行中"

    # 显示 Docker 信息
    echo -e "\n服务器版本: $(docker info --format '{{.ServerVersion}}')"
    echo "存储驱动: $(docker info --format '{{.Driver}}')"
    echo "运行中容器: $(docker info --format '{{.ContainersRunning}}')"
    echo "镜像数量: $(docker info --format '{{.Images}}')"
}

# 检查磁盘空间
check_disk_space() {
    print_header "磁盘空间检测"

    # Docker 系统使用情况
    echo "Docker 磁盘使用:"
    docker system df

    # 检查是否需要清理
    local total_size=$(docker system df --format '{{.Size}}' | head -1)
    echo -e "\n总使用空间: $total_size"

    # 计算可回收空间
    local reclaimable=$(docker system df --format '{{.Reclaimable}}' | head -1)
    if [[ "$reclaimable" != "0B" ]]; then
        print_warn "可回收空间: $reclaimable"
        echo "  运行 'docker system prune' 清理未使用资源"
    else
        print_ok "无需清理"
    fi
}

# 检查运行中的容器
check_containers() {
    print_header "容器状态检测"

    local container_count=$(docker ps -q | wc -l)
    if [[ $container_count -eq 0 ]]; then
        print_warn "没有运行中的容器"
        return
    fi

    echo "运行中容器 ($container_count 个):"
    echo ""
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

    # 检查不健康的容器
    echo ""
    local unhealthy=$(docker ps --filter "health=unhealthy" -q | wc -l)
    if [[ $unhealthy -gt 0 ]]; then
        print_error "发现 $unhealthy 个不健康容器:"
        docker ps --filter "health=unhealthy" --format "  - {{.Names}}: {{.Status}}"
    fi

    # 检查重启过多的容器
    docker ps --format '{{.Names}} {{.Status}}' | while read name status; do
        if [[ "$status" == *"Restarting"* ]]; then
            print_error "容器 $name 正在重启循环中"
        fi
    done
}

# 检查特定容器
check_specific_container() {
    local container=$1
    print_header "容器详情: $container"

    # 检查容器是否存在
    if ! docker inspect "$container" &> /dev/null; then
        print_error "容器 '$container' 不存在"
        return 1
    fi

    # 基本信息
    echo "镜像: $(docker inspect -f '{{.Config.Image}}' "$container")"
    echo "状态: $(docker inspect -f '{{.State.Status}}' "$container")"
    echo "创建时间: $(docker inspect -f '{{.Created}}' "$container")"

    # 退出码（如果已停止）
    local status=$(docker inspect -f '{{.State.Status}}' "$container")
    if [[ "$status" == "exited" ]]; then
        local exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$container")
        echo "退出码: $exit_code"
        case $exit_code in
            0) print_ok "正常退出" ;;
            1) print_error "应用错误 - 检查日志" ;;
            137) print_error "OOM Killed - 增加内存限制" ;;
            139) print_error "段错误 - 检查二进制兼容性" ;;
            *) print_warn "未知退出码" ;;
        esac
    fi

    # 健康检查状态
    local health=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
    if [[ "$health" != "none" && "$health" != "" ]]; then
        echo "健康状态: $health"
        if [[ "$health" == "unhealthy" ]]; then
            print_error "健康检查失败"
            echo "最近检查日志:"
            docker inspect -f '{{range .State.Health.Log}}{{.Output}}{{end}}' "$container" | tail -5
        fi
    fi

    # 资源使用
    if [[ "$status" == "running" ]]; then
        echo -e "\n资源使用:"
        docker stats "$container" --no-stream --format "  CPU: {{.CPUPerc}}, 内存: {{.MemUsage}}"
    fi

    # 最近日志
    echo -e "\n最近日志 (最后10行):"
    docker logs "$container" --tail 10 2>&1 | sed 's/^/  /'
}

# 检查网络
check_networks() {
    print_header "网络检测"

    echo "Docker 网络:"
    docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"

    # 检查是否有孤立网络
    local orphan_networks=$(docker network ls --filter "dangling=true" -q | wc -l)
    if [[ $orphan_networks -gt 0 ]]; then
        print_warn "发现 $orphan_networks 个孤立网络"
    fi
}

# 检查镜像
check_images() {
    print_header "镜像检测"

    # 悬空镜像
    local dangling=$(docker images -f "dangling=true" -q | wc -l)
    if [[ $dangling -gt 0 ]]; then
        print_warn "发现 $dangling 个悬空镜像（可清理）"
    fi

    # 最大的镜像
    echo -e "\n最大的5个镜像:"
    docker images --format "{{.Size}}\t{{.Repository}}:{{.Tag}}" | sort -hr | head -5
}

# 生成诊断报告
generate_report() {
    print_header "诊断摘要"

    local issues=0

    # 检查各项指标
    if ! docker info &> /dev/null; then
        print_error "Docker 守护进程未运行"
        ((issues++))
    fi

    local unhealthy=$(docker ps --filter "health=unhealthy" -q 2>/dev/null | wc -l)
    if [[ $unhealthy -gt 0 ]]; then
        print_error "$unhealthy 个容器健康检查失败"
        ((issues++))
    fi

    local exited=$(docker ps -a --filter "status=exited" -q | wc -l)
    if [[ $exited -gt 5 ]]; then
        print_warn "$exited 个已停止容器（建议清理）"
    fi

    local dangling=$(docker images -f "dangling=true" -q | wc -l)
    if [[ $dangling -gt 0 ]]; then
        print_warn "$dangling 个悬空镜像（建议清理）"
    fi

    if [[ $issues -eq 0 ]]; then
        print_ok "未发现严重问题"
    else
        echo -e "\n发现 $issues 个需要关注的问题"
    fi
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "========================================"
    echo "       Docker 一键诊断工具 v1.0        "
    echo "========================================"
    echo -e "${NC}"

    # 如果提供了容器名，只检查该容器
    if [[ -n "$1" ]]; then
        check_specific_container "$1"
        exit 0
    fi

    # 完整诊断
    check_docker
    check_disk_space
    check_containers
    check_networks
    check_images
    generate_report
}

main "$@"
