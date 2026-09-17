#!/bin/bash
# scripts/fetch-arm64-pikafish.sh — 从 GitHub Actions 下载 arm64 NEON 版 Pikafish 静态库
#
# 用法：bash scripts/fetch-arm64-pikafish.sh
# 前置：GitHub Actions workflow build-pikafish-arm64.yml 已成功运行
#
# 作用：
# 1. 从 GitHub Actions 下载 arm64 版 libpikafish.a（含 entry_arm64.cpp NEON 优化）
# 2. 与本地 x86_64 版本合并为 universal binary
# 3. 替换 src/ChineseChess/Pikafish/lib/macos/libpikafish.a

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB_DIR="$PROJECT_ROOT/src/ChineseChess/Pikafish/lib"
TMP_DIR=$(mktemp -d)

trap "rm -rf $TMP_DIR" EXIT

echo "=== 下载 Pikafish arm64 NEON 静态库 ==="

# 检查 gh CLI
if ! command -v gh &> /dev/null; then
    echo "❌ 需要 GitHub CLI (gh)。安装: brew install gh"
    exit 1
fi

# 认证检查
if ! gh auth status &> /dev/null; then
    echo "❌ GitHub CLI 未认证。运行: gh auth login"
    exit 1
fi

# 找到最新的 successful run
echo "查找最新的 build-pikafish-arm64 运行..."
RUN_ID=$(gh run list \
    --workflow="build-pikafish-arm64.yml" \
    --status=success \
    --limit=1 \
    --json databaseId \
    --jq '.[0].databaseId' 2>/dev/null)

if [[ -z "$RUN_ID" ]]; then
    echo "❌ 未找到成功的 build-pikafish-arm64 运行"
    echo "   请先在 GitHub Actions 页面手动触发 workflow"
    exit 1
fi

echo "找到运行 ID: $RUN_ID"

# 下载 artifact
echo "下载 artifact..."
gh run download "$RUN_ID" \
    --name "pikafish-arm64-neon" \
    --dir "$TMP_DIR" \
    2>&1

ARM64_LIB="$TMP_DIR/libpikafish.a"
BUILD_INFO="$TMP_DIR/build-info.md"

if [[ ! -f "$ARM64_LIB" ]]; then
    echo "❌ 下载的 artifact 中未找到 libpikafish.a"
    exit 1
fi

echo "=== arm64 NEON 版本信息 ==="
cat "$BUILD_INFO" 2>/dev/null || echo "(无 build-info.md)"
echo ""
lipo -info "$ARM64_LIB"

# 验证 entry_arm64 符号
echo "=== entry_arm64 符号检查 ==="
if nm "$ARM64_LIB" | grep -q "entry_arm64"; then
    echo "✅ entry_arm64 符号存在（NEON 优化已包含）"
else
    echo "⚠️  entry_arm64 符号未找到（可能 NEON 优化未编译进来）"
    read -p "是否继续？(y/N) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# 与本地 x86_64 合并
X86_LIB="$LIB_DIR/macos-x86_64/libpikafish.a"
if [[ ! -f "$X86_LIB" ]]; then
    echo "❌ 本地 x86_64 库不存在: $X86_LIB"
    echo "   请先运行 bash src/ChineseChess/Pikafish/build.sh 编译 x86_64 版本"
    exit 1
fi

echo "=== 创建 universal binary ==="
BACKUP="$LIB_DIR/macos/libpikafish.a.backup-$(date +%Y%m%d%H%M%S)"
if [[ -f "$LIB_DIR/macos/libpikafish.a" ]]; then
    cp "$LIB_DIR/macos/libpikafish.a" "$BACKUP"
    echo "已备份旧版本: $BACKUP"
fi

mkdir -p "$LIB_DIR/macos"
lipo -create "$ARM64_LIB" "$X86_LIB" -output "$LIB_DIR/macos/libpikafish.a"

echo "=== 验证最终产物 ==="
lipo -info "$LIB_DIR/macos/libpikafish.a"
echo ""
echo "✅ Universal binary 已更新: $LIB_DIR/macos/libpikafish.a"
echo ""
echo "下一步：重新打包以使用新的 arm64 NEON 优化版本"
echo "  bash scripts/build-release.sh v3.x.x"
