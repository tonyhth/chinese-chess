#!/bin/bash
# verify_delivery.sh — 交付验证脚本
# 用法: bash verify_delivery.sh <app路径> <源码目录> [验证字符串...]
#
# 交付前必须跑，全部通过才能交付给用户。
# 解决的问题：虚假修复、缓存产物、版本混乱

set -euo pipefail

APP_PATH="$1"
SOURCE_DIR="$2"
shift 2
VERIFY_STRINGS=("$@")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check_pass() { echo -e "${GREEN}✅ $1${NC}"; PASS=$((PASS+1)); }
check_fail() { echo -e "${RED}❌ FAIL: $1${NC}"; FAIL=$((FAIL+1)); }

# Prefer main executable, but fallback to debug dylib if main is too small (code in separate dylib)
BINARY=$(find "$APP_PATH/Contents/MacOS" -type f -perm +111 -not -name '*.dylib' -not -name '__*' | head -1)
if [ -n "$BINARY" ]; then
    BINSIZE=$(stat -f "%z" "$BINARY" 2>/dev/null || echo 0)
    if [ "$BINSIZE" -lt 102400 ]; then
        # Main binary < 100KB, code is in debug dylib
        DYLIB=$(find "$APP_PATH/Contents/MacOS" -name '*.debug.dylib' -type f | head -1)
        [ -n "$DYLIB" ] && BINARY="$DYLIB"
    fi
fi
if [ -z "$BINARY" ]; then
    BINARY=$(find "$APP_PATH/Contents/MacOS" -type f -perm +111 | head -1)
fi
if [ -z "$BINARY" ]; then
    check_fail "找不到 binary: $APP_PATH"
    exit 1
fi

echo "========================================="
echo "交付验证: $(basename "$APP_PATH")"
echo "Binary: $BINARY"
echo "========================================="
echo ""

# ---- 1. Binary mtime >= 所有源码 mtime ----
echo "【检查1】binary 时间戳 vs 源码时间戳"
BIN_MTIME=$(stat -f "%m" "$BINARY")
VIOLATIONS=0
while IFS= read -r src; do
    SRC_MTIME=$(stat -f "%m" "$src")
    if [ "$SRC_MTIME" -gt "$BIN_MTIME" ]; then
        SRC_REL="${src#$SOURCE_DIR/}"
        check_fail "$SRC_REL (源码 $(stat -f "%Sm" "$src")) 晚于 binary ( $(stat -f "%Sm" "$BINARY"))"
        VIOLATIONS=$((VIOLATIONS+1))
    fi
done < <(find "$SOURCE_DIR" -name "*.swift" -type f)

if [ "$VIOLATIONS" -eq 0 ]; then
    check_pass "所有源码 mtime ≤ binary mtime"
else
    check_fail "$VIOLATIONS 个源码文件比 binary 更新"
fi
echo ""

# ---- 2. 验证声称的修复是否在 binary 中 ----
if [ ${#VERIFY_STRINGS[@]} -gt 0 ]; then
    echo "【检查2】修复内容验证"
    STRINGS_CACHE=$(mktemp)
    strings "$BINARY" > "$STRINGS_CACHE" 2>/dev/null || true
    for str in "${VERIFY_STRINGS[@]}"; do
        if grep -q "$str" "$STRINGS_CACHE" 2>/dev/null; then
            check_pass "'$str' 在 binary 中找到"
        else
            check_fail "'$str' 在 binary 中未找到 — 修复可能未编译进 binary"
        fi
    done
    rm -f "$STRINGS_CACHE"
    echo ""
fi

# ---- 3. Bundle 资源完整性 ----
echo "【检查3】Bundle 资源完整性"
if [ -f "$APP_PATH/Contents/Resources/wordlist.json" ]; then
    WORD_COUNT=$(python3 -c "import json; print(len(json.load(open('$APP_PATH/Contents/Resources/wordlist.json'))))" 2>/dev/null || echo "0")
    if [ "$WORD_COUNT" -gt 0 ]; then
        check_pass "wordlist.json 存在 ($WORD_COUNT 个单词)"
    else
        check_fail "wordlist.json 为空或无法解析"
    fi
else
    check_fail "wordlist.json 不在 bundle 中"
fi
echo ""

# ---- 4. 自定义图标 ----
echo "【检查4】自定义图标"
if [ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    check_pass "AppIcon.icns 存在"
else
    check_fail "AppIcon.icns 不存在 — 缺少自定义图标"
fi
echo ""

# ---- 5. .app 能启动 ----
echo "【检查5】二进制可执行性"
if file "$BINARY" | grep -q "Mach-O"; then
    check_pass "Binary 是有效的 Mach-O 可执行文件"
else
    check_fail "Binary 不是有效的 Mach-O 文件"
fi
echo ""

# ---- 汇总 ----
echo "========================================="
echo -e "结果: ${GREEN}$PASS 通过${NC} / ${RED}$FAIL 失败${NC}"
echo "========================================="

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}🚫 验证未通过，不能交付${NC}"
    exit 1
else
    echo -e "${GREEN}✅ 验证通过，可以交付${NC}"
    exit 0
fi
