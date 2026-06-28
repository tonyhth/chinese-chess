#!/bin/bash
# verify_delivery.sh — 交付门禁脚本
# 用法: ./verify_delivery.sh [project-dir]
# 默认 project-dir: ~/DevTeam/projects/chinese-chess
#
# 检查项：
#   1. 编译验证（swift build 零错误）
#   2. Git 工作区干净（无未提交改动）
#   3. 禁止文件未被跟踪（.build, *.o, *.a, DerivedData 等）
#   4. NNUE 文件存在且非空
#   5. .gitignore 覆盖关键路径

set -euo pipefail

PROJECT_DIR="${1:-$HOME/DevTeam/projects/chinese-chess}"
SRC_DIR="$PROJECT_DIR/src"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

ok()   { echo -e "${GREEN}✅ $1${NC}"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}❌ $1${NC}"; FAIL=$((FAIL+1)); }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; WARN=$((WARN+1)); }

echo "═══════════════════════════════════════════"
echo "  交付门禁检查 — $(date '+%Y-%m-%d %H:%M')"
echo "  项目: $PROJECT_DIR"
echo "═══════════════════════════════════════════"

# --------------------------------------------------
# 1. 编译验证
# --------------------------------------------------
echo ""
echo "📦 [1/5] 编译验证"
echo "  运行: swift build"
if (cd "$SRC_DIR" && swift build 2>&1 | grep -q "Build complete!"); then
    ok "swift build 成功"
else
    fail "swift build 失败"
fi

# --------------------------------------------------
# 2. Git 工作区状态
# --------------------------------------------------
echo ""
echo "📂 [2/5] Git 工作区状态"
UNCOMMITTED=$(cd "$PROJECT_DIR" && git status --porcelain | wc -l | tr -d ' ')
if [ "$UNCOMMITTED" -eq 0 ]; then
    ok "工作区干净，无未提交改动"
else
    warn "有 $UNCOMMITTED 个未提交/未跟踪文件"
    cd "$PROJECT_DIR" && git status --short | head -10
fi

# --------------------------------------------------
# 3. 禁止文件检查
# --------------------------------------------------
echo ""
echo "🚫 [3/5] 禁止文件检查"
FORBIDDEN_PATTERNS=(
    "*.o"
    "*.a"
    "*.profraw"
    "debug.log"
    "training.log"
)
FORBIDDEN_DIRS=(
    ".build"
    "*.build"
    ".build-release"
    "DerivedData"
    "ChineseChess-iOS"
)

FOUND_FORBIDDEN=0
cd "$PROJECT_DIR"

# 检查 git 跟踪的禁止文件
for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    if git ls-files -- "$pattern" 2>/dev/null | grep -q .; then
        fail "Git 跟踪了禁止文件: $pattern"
        git ls-files -- "$pattern" | head -5
        FOUND_FORBIDDEN=1
    fi
done

for dir in "${FORBIDDEN_DIRS[@]}"; do
    if git ls-files -- "$dir/" 2>/dev/null | grep -q .; then
        fail "Git 跟踪了禁止目录: $dir/"
        FOUND_FORBIDDEN=1
    fi
done

if [ "$FOUND_FORBIDDEN" -eq 0 ]; then
    ok "无禁止文件被 Git 跟踪"
fi

# --------------------------------------------------
# 4. NNUE 文件检查
# --------------------------------------------------
echo ""
echo "♟️  [4/5] NNUE 引擎文件检查"
NNUE_PATH="$SRC_DIR/ChineseChess/Resources/pikafish.nnue"
if [ -f "$NNUE_PATH" ]; then
    NNUE_SIZE=$(stat -f%z "$NNUE_PATH" 2>/dev/null || stat -c%s "$NNUE_PATH" 2>/dev/null || echo 0)
    if [ "$NNUE_SIZE" -gt 1000000 ]; then
        ok "pikafish.nnue 存在 ($(( NNUE_SIZE / 1024 / 1024 ))MB)"
    else
        fail "pikafish.nnue 过小 ($NNUE_SIZE bytes)，可能损坏"
    fi
else
    fail "pikafish.nnue 不存在: $NNUE_PATH"
fi

# --------------------------------------------------
# 5. .gitignore 覆盖检查
# --------------------------------------------------
echo ""
echo "📝 [5/5] .gitignore 覆盖检查"
GITIGNORE="$PROJECT_DIR/.gitignore"
REQUIRED_IGNORES=(
    ".build/"
    "*.build/"
    "*.o"
    "*.a"
    "DerivedData/"
)

GI_MISSING=0
for pattern in "${REQUIRED_IGNORES[@]}"; do
    if ! grep -qF "$pattern" "$GITIGNORE" 2>/dev/null; then
        warn ".gitignore 缺少: $pattern"
        GI_MISSING=1
    fi
done

if [ "$GI_MISSING" -eq 0 ]; then
    ok ".gitignore 覆盖所有关键路径"
fi

# --------------------------------------------------
# 汇总
# --------------------------------------------------
echo ""
echo "═══════════════════════════════════════════"
echo -e "  ${GREEN}通过: $PASS${NC}  ${RED}失败: $FAIL${NC}  ${YELLOW}警告: $WARN${NC}"
echo "═══════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}🚫 交付门禁未通过 — 存在 $FAIL 个失败项${NC}"
    exit 1
else
    echo -e "${GREEN}✅ 交付门禁通过${NC}"
    exit 0
fi
