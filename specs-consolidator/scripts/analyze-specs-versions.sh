#!/bin/bash

# Specs 版本分析脚本
# 用途：扫描 specs/ 目录，分析 updatePRD 文档的版本情况

set -e

echo "=== Specs 版本分析工具 ==="
echo ""

# 检查是否在项目根目录
if [ ! -d "specs" ]; then
    echo "错误：未找到 specs/ 目录"
    echo "请在项目根目录运行此脚本"
    exit 1
fi

# 1. 扫描 updatePRD 文件
echo "## 1. 扫描 updatePRD 文件"
echo ""

updateprd_files=$(find specs -name "updatePRDv*.md" -not -name "*-PLAN.md" -not -name "*-consolidated.md" | sort)
plan_files=$(find specs -name "updatePRDv*-PLAN.md" | sort)

if [ -z "$updateprd_files" ]; then
    echo "✅ 未找到待整合的 updatePRD 文件"
    echo ""
else
    echo "📄 找到以下 updatePRD 文件："
    echo "$updateprd_files" | while read file; do
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "  - $file ($size)"
    done
    echo ""
fi

if [ -n "$plan_files" ]; then
    echo "📋 找到以下 PLAN 文件："
    echo "$plan_files" | while read file; do
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "  - $file ($size)"
    done
    echo ""
fi

# 2. 读取 consolidated 文档当前版本
echo "## 2. Consolidated 文档状态"
echo ""

if [ -f "specs/updatePRD-consolidated.md" ]; then
    current_version=$(grep -m 1 "^> \*\*版本\*\*:" specs/updatePRD-consolidated.md | sed 's/.*v\([0-9.]*\).*/\1/')
    current_date=$(grep -m 1 "^> \*\*日期\*\*:" specs/updatePRD-consolidated.md | sed 's/.*：\(.*\)/\1/')

    echo "📚 当前版本：v$current_version"
    echo "📅 更新日期：$current_date"
    echo ""
else
    echo "⚠️  未找到 updatePRD-consolidated.md"
    echo ""
fi

# 3. 分析版本号
echo "## 3. 版本号分析"
echo ""

if [ -n "$updateprd_files" ]; then
    echo "建议的版本号映射："
    echo ""

    # 提取 updatePRD 文件序号并排序
    versions=$(echo "$updateprd_files" | sed -n 's/.*updatePRDv\([0-9][0-9]*\)\.md/\1/p' | sort -n)

    # 计算新版本号：consolidated 主版本 + 1，updatePRDvN -> v{新主版本}.N
    if [ -n "$current_version" ]; then
        major=$(echo "$current_version" | cut -d. -f1)
        new_major=$((major + 1))
    else
        new_major=1
    fi

    echo "| 原文件 | 建议版本 | 说明 |"
    echo "|--------|---------|------|"

    last_version=""
    for v in $versions; do
        new_version="$new_major.$v"
        last_version="$new_version"
        file="specs/updatePRDv$v.md"

        # 尝试提取文件标题
        if [ -f "$file" ]; then
            title=$(grep -m 1 "^# " "$file" | sed 's/^# //' | head -c 50)
            echo "| updatePRDv$v.md | v$new_version | $title |"
        fi
    done
    echo ""

    echo "🎯 目标版本：v$last_version"
    echo ""
fi

# 4. 统计信息
echo "## 4. 统计信息"
echo ""

if [ -n "$updateprd_files" ]; then
    file_count=$(echo "$updateprd_files" | wc -l)
    total_size=$(echo "$updateprd_files" | xargs ls -l | awk '{sum+=$5} END {print sum}')
    total_size_kb=$((total_size / 1024))

    echo "📊 待整合文件：$file_count 个"
    echo "💾 总大小：${total_size_kb}KB"
    echo ""
fi

# 5. 建议操作
echo "## 5. 建议操作"
echo ""

if [ -n "$updateprd_files" ]; then
    echo "执行以下步骤整合文档："
    echo ""
    echo "1. 读取所有 updatePRD 文件内容"
    echo "2. 确定版本号映射关系"
    echo "3. 整合内容到 consolidated.md"
    echo "4. 更新 PRD.md 和 AGENTS.md"
    echo "5. 删除已整合的文件"
    echo "6. 提交变更"
    echo ""
    echo "💡 提示：使用 'specs-consolidator' skill 自动执行整合流程"
else
    echo "✅ 所有文档已整合，无需操作"
fi

echo ""
echo "=== 分析完成 ==="
