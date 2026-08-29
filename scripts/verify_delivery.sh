#!/bin/bash
# verify_delivery.sh — 交付门禁脚本
# 用法: ./verify_delivery.sh [project-dir]
# 默认 project-dir: ~/DevTeam/projects/chinese-chess
#
# 检查项：
#   1. 编译验证（xcodegen + xcodebuild 零错误）
#   2. Git 工作区干净（无未提交改动）
#   3. 禁止文件未被跟踪（*.o, *.a, DerivedData 等）
#   4. NNUE 文件存在且非空
#   5. .gitignore 覆盖关键路径

set -euo pipefail

# ---- v6.3 C5: 参数校验 ----
if [ $# -gt 1 ]; then
    echo "用法: $0 [project-dir]（默认 ~/DevTeam/projects/chinese-chess）"
    exit 2
fi
PROJECT_DIR="${1:-$HOME/DevTeam/projects/chinese-chess}"
if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ 项目目录不存在: $PROJECT_DIR"
    exit 2
fi
if [ ! -f "$PROJECT_DIR/project.yml" ] && [ ! -f "$PROJECT_DIR/ChineseChess.xcodeproj/project.pbxproj" ]; then
    echo "❌ 目录缺少 project.yml / ChineseChess.xcodeproj，疑似非本项目根: $PROJECT_DIR"
    exit 2
fi

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
# 1. 编译验证 (xcodegen + xcodebuild)
# --------------------------------------------------
echo ""
echo "📦 [1/5] 编译验证"
echo "  运行: xcodegen generate + xcodebuild"
cd "$PROJECT_DIR"
if xcodegen generate 2>&1 | grep -q "Created project" && \
   xcodebuild -target ChineseChess -configuration Release -sdk macosx build \
     CONFIGURATION_BUILD_DIR="$PROJECT_DIR/build/Release" 2>&1 | grep -q "BUILD SUCCEEDED"; then
    ok "xcodegen + xcodebuild Release 成功"
else
    fail "xcodegen + xcodebuild 失败"
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
    "*.xcodeproj"
)

FOUND_FORBIDDEN=0
cd "$PROJECT_DIR"

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
NNUE_PATH="$PROJECT_DIR/src/ChineseChess/Resources/pikafish.nnue"
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
    "*.xcodeproj/"
    "*.o"
    "*.a"
    "DerivedData/"
    "build/"
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
# 5.5 manifest 单源对账（v6.3 Step 4：L1 消费 asset-manifest.json，与 L4/E1 同源）
# --------------------------------------------------
echo ""
echo "🧾 [5.5/6] manifest 单源对账（L1 源侧）"
MANIFEST="$PROJECT_DIR/src/ChineseChess/Resources/asset-manifest.json"
if [ ! -f "$MANIFEST" ]; then
    fail "asset-manifest.json 不存在: $MANIFEST"
else
    # python3 单发对账：逐条校验 repoPath 存在 + bytes + sha256；dirs 校验 minFiles
    if MANIFEST="$MANIFEST" PROJECT_DIR="$PROJECT_DIR" python3 - <<'PYEOF'
import hashlib, json, os, sys
m = json.load(open(os.environ["MANIFEST"]))
root = os.environ["PROJECT_DIR"]
bad = 0
for a in m.get("assets", []):
    p = os.path.join(root, a["repoPath"])
    if not os.path.isfile(p):
        print(f"  ❌ [{a['name']}] 源文件缺失: {a['repoPath']}"); bad += 1; continue
    sz = os.path.getsize(p)
    if sz != a["bytes"]:
        print(f"  ❌ [{a['name']}] 大小不符: repo={sz} manifest={a['bytes']}"); bad += 1; continue
    h = hashlib.sha256(open(p, "rb").read()).hexdigest()
    if h != a["sha256"]:
        print(f"  ❌ [{a['name']}] sha256 不符: repo={h[:16]}… manifest={a['sha256'][:16]}…"); bad += 1
for d in m.get("dirs", []):
    p = os.path.join(root, d["repoPath"])
    if not os.path.isdir(p):
        print(f"  ❌ [{d['name']}] 目录缺失: {d['repoPath']}"); bad += 1; continue
    import glob as _g
    if "repoGlob" in d:
        n = len(_g.glob(os.path.join(p, d["repoGlob"])))
    else:
        n = len([f for f in os.listdir(p) if not f.startswith(".")])
    if n < d["minFiles"]:
        print(f"  ❌ [{d['name']}] 文件数 {n} < minFiles {d['minFiles']}"); bad += 1
sys.exit(1 if bad else 0)
PYEOF
    then
        ok "manifest 对账通过：$(python3 -c "import json;m=json.load(open('$MANIFEST'));print(len(m['assets']), 'assets +', len(m['dirs']), 'dirs')")"
    else
        fail "manifest 对账失败（上方 ❌ 条目，拔资产/源料损坏形态）"
    fi
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
