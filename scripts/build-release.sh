#!/bin/bash
#
# build-release.sh — 标准化打包脚本 (xcodegen 版本)
#
# 用法：bash scripts/build-release.sh <版本号>
# 例如：bash scripts/build-release.sh 3.5.0
#
# 输出：~/DevTeam/projects/chinese-chess/中国象棋-v{版本号}.app
#

set -euo pipefail

# ============ 参数校验 ============
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "❌ 用法: bash scripts/build-release.sh <版本号>"
    echo "   例如: bash scripts/build-release.sh 3.5.0"
    exit 1
fi

# ============ 路径定义 ============
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="中国象棋-v${VERSION}.app"
APP_DIR="$PROJECT_ROOT/$APP_NAME"
ICONSET_DIR="$PROJECT_ROOT/src/ChineseChess/Resources/Assets.xcassets/AppIcon.appiconset"

# xcodegen 产物路径
BUILD_DIR="$PROJECT_ROOT/build"
XC_APP="$BUILD_DIR/Release/ChineseChess.app"

echo "=========================================="
echo "  中国象棋 v${VERSION} 打包 (xcodegen)"
echo "=========================================="
echo "项目根目录: $PROJECT_ROOT"
echo "输出路径:   $APP_DIR"
echo ""

# ============ 1. 构建 (xcodegen + xcodebuild) ============
echo "📦 [1/6] xcodebuild Release..."
cd "$PROJECT_ROOT"
xcodegen generate 2>&1
xcodebuild -target ChineseChess -sdk macosx -configuration Release build \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR/Release" 2>&1 | tail -5

if [[ ! -d "$XC_APP" ]]; then
    echo "❌ 构建失败：ChineseChess.app 不存在"
    exit 1
fi
echo "   ✅ 构建成功"
echo ""

# ============ 2. 资源完整性验证 ============
echo "🔍 [2/6] 验证 App bundle 资源完整性..."
RES_DIR="$XC_APP/Contents/Resources"

REQUIRED_FILES=(
    "LXGWWenKai-Regular.ttf"
    "opening_book_v2.json"
    "openings.json"
    "puzzles.json"
    "move.wav"
    "capture.wav"
    "check.wav"
    "checkmate.wav"
    "victory.wav"
    "defeat.wav"
    "undo.wav"
    "pikafish.nnue"
    "zh-Hans.lproj/Localizable.strings"
    "en.lproj/Localizable.strings"
)

MISSING=0
for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$RES_DIR/$f" ]]; then
        echo "   ❌ 缺失: $f"
        MISSING=$((MISSING + 1))
    fi
done

if [[ $MISSING -gt 0 ]]; then
    echo "❌ 资源完整性验证失败：缺失 $MISSING 个文件"
    exit 1
fi
TOTAL=${#REQUIRED_FILES[@]}
echo "   ✅ 全部 $TOTAL 个资源就绪"
echo ""

# ============ 3. 生成图标 ============
echo "🎨 [3/6] 生成 AppIcon.icns..."

ICONSET_TMP=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET_TMP"

cp "$ICONSET_DIR/icon_16x16.png"       "$ICONSET_TMP/icon_16x16.png"
cp "$ICONSET_DIR/icon_16x16@2x.png"    "$ICONSET_TMP/icon_16x16@2x.png"
cp "$ICONSET_DIR/icon_32x32.png"       "$ICONSET_TMP/icon_32x32.png"
cp "$ICONSET_DIR/icon_32x32@2x.png"    "$ICONSET_TMP/icon_32x32@2x.png"
cp "$ICONSET_DIR/icon_128x128.png"     "$ICONSET_TMP/icon_128x128.png"
cp "$ICONSET_DIR/icon_128x128@2x.png"  "$ICONSET_TMP/icon_128x128@2x.png"
cp "$ICONSET_DIR/icon_256x256.png"     "$ICONSET_TMP/icon_256x256.png"
cp "$ICONSET_DIR/icon_256x256@2x.png"  "$ICONSET_TMP/icon_256x256@2x.png"
cp "$ICONSET_DIR/icon_512x512.png"     "$ICONSET_TMP/icon_512x512.png"
cp "$ICONSET_DIR/icon_512x512@2x.png"  "$ICONSET_TMP/icon_512x512@2x.png"

ICNS_OUTPUT=$(mktemp -d)/AppIcon.icns
if iconutil -c icns "$ICONSET_TMP" -o "$ICNS_OUTPUT" 2>&1; then
    echo "   ✅ iconutil 生成成功 ($(ls -la "$ICNS_OUTPUT" | awk '{print $5}') bytes)"
else
    echo "⚠️  iconutil 生成失败，尝试使用预编译 icns..."
    PREV_ICNS=$(find "$PROJECT_ROOT" -name "AppIcon.icns" -path "*.app/*" 2>/dev/null | head -1)
    if [[ -n "$PREV_ICNS" ]]; then
        cp "$PREV_ICNS" "$ICNS_OUTPUT"
        echo "   ✅ 使用预编译 icns"
    else
        echo "❌ 无法生成或找到 AppIcon.icns"
        rm -rf "$(dirname "$ICONSET_TMP")"
        exit 1
    fi
fi
rm -rf "$(dirname "$ICONSET_TMP")"
echo ""

# ============ 4. 复制 App 到输出目录 ============
echo "🏗️  [4/6] 复制到输出目录..."

if [[ -d "$APP_DIR" ]]; then
    rm -rf "$APP_DIR"
fi

cp -R "$XC_APP" "$APP_DIR"

# 覆盖图标（xcodegen 默认不生成 icns）
cp "$ICNS_OUTPUT" "$APP_DIR/Contents/Resources/AppIcon.icns"
rm -f "$ICNS_OUTPUT"
echo "   ✅ .app 已复制"
echo ""

# ============ 5. 更新 Info.plist ============
echo "📋 [5/6] 更新 Info.plist..."

/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $VERSION" \
    -c "Set :CFBundleVersion $VERSION" \
    -c "Set :CFBundleDisplayName 中国象棋" \
    "$APP_DIR/Contents/Info.plist" 2>/dev/null
echo "   ✅ 版本号已更新为 $VERSION"
echo ""

# ============ 6. 签名 + 最终验证 ============
echo "🔐 [6/6] 签名 + 验证..."

codesign --force --deep --sign - "$APP_DIR" && echo "   ✅ Ad-hoc 签名完成" || echo "   ⚠️ 签名失败"

# 刷新 LaunchServices
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -f "$APP_DIR" 2>/dev/null
    echo "   ✅ LaunchServices 已刷新"
fi

# 汇总
echo ""
echo "=========================================="
echo "  ✅ 打包成功！"
echo "=========================================="
echo "路径: $APP_DIR"
echo "大小: $(du -sh "$APP_DIR" | awk '{print $1}')"
echo "版本: $VERSION"
echo ""
echo "内容:"
echo "  Contents/MacOS/ChineseChess"
echo "  Contents/Resources/AppIcon.icns"
echo "  Contents/Resources/Localizable.xcstrings"
echo "  Contents/Resources/LXGWWenKai-Regular.ttf"
echo "  Contents/Resources/pikafish.nnue"
echo "  Contents/Resources/Sounds/ ($(ls "$APP_DIR/Contents/Resources/"*.wav 2>/dev/null | wc -l | tr -d ' ') wavs)"
echo "  Contents/Resources/OpeningBook/ ($(ls "$APP_DIR/Contents/Resources/OpeningBook/" 2>/dev/null | wc -l | tr -d ' ') files)"
echo "  Contents/Resources/Puzzles/ ($(ls "$APP_DIR/Contents/Resources/Puzzles/" 2>/dev/null | wc -l | tr -d ' ') files)"
echo "=========================================="

open "$PROJECT_ROOT"
