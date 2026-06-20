#!/bin/bash
#
# build-release.sh — 标准化打包脚本
#
# 用法：bash scripts/build-release.sh <版本号>
# 例如：bash scripts/build-release.sh 2.2.21
#
# 输出：~/DevTeam/projects/chinese-chess/中国象棋-v{版本号}.app
#

set -euo pipefail

# ============ 参数校验 ============
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "❌ 用法: bash scripts/build-release.sh <版本号>"
    echo "   例如: bash scripts/build-release.sh 2.2.21"
    exit 1
fi

# ============ 路径定义 ============
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
APP_NAME="中国象棋-v${VERSION}.app"
APP_DIR="$PROJECT_ROOT/$APP_NAME"
ICONSET_DIR="$SRC_DIR/ChineseChess/Resources/Assets.xcassets/AppIcon.appiconset"
BUNDLE_NAME="ChineseChess_ChineseChess.bundle"

echo "=========================================="
echo "  中国象棋 v${VERSION} 打包"
echo "=========================================="
echo "项目根目录: $PROJECT_ROOT"
echo "输出路径:   $APP_DIR"
echo ""

# ============ 1. 构建 ============
echo "📦 [1/7] 构建_release..."
cd "$SRC_DIR"
swift build -c release 2>&1 | tail -3
if [[ ! -f ".build/release/ChineseChess" ]]; then
    echo "❌ 构建失败：binary 不存在"
    exit 1
fi
echo "   ✅ 构建成功"
echo ""

# ============ 2. 资源完整性验证 ============
echo "🔍 [2/7] 验证 SPM bundle 资源完整性..."
BUNDLE_PATH=".build/release/$BUNDLE_NAME"

REQUIRED_FILES=(
    "Localizable.xcstrings"
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
)

MISSING=0
for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$BUNDLE_PATH/$f" ]]; then
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
echo "🎨 [3/7] 生成 AppIcon.icns..."

# iconutil 需要 .iconset 格式目录（只含 mac 图标，标准命名）
ICONSET_TMP=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET_TMP"

# 复制 mac 图标到 .iconset（iconutil 要求的命名格式）
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
    # Fallback: 查找已有的 icns
    PREV_ICNS=$(find "$PROJECT_ROOT" -name "AppIcon.icns" -path "*.app/*" 2>/dev/null | head -1)
    if [[ -n "$PREV_ICNS" ]]; then
        cp "$PREV_ICNS" "$ICNS_OUTPUT"
        echo "   ✅ 使用预编译 icns: $(basename $(dirname $(dirname "$PREV_ICNS")))"
    else
        echo "❌ 无法生成或找到 AppIcon.icns"
        rm -rf "$(dirname "$ICONSET_TMP")"
        exit 1
    fi
fi
rm -rf "$(dirname "$ICONSET_TMP")"
echo ""

# ============ 4. 清理旧包 ============
echo "🧹 [4/7] 清理旧包..."
if [[ -d "$APP_DIR" ]]; then
    rm -rf "$APP_DIR"
    echo "   已删除旧包"
else
    echo "   无旧包"
fi
echo ""

# ============ 5. 组装 .app ============
echo "🏗️  [5/7] 组装 .app..."

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Binary
cp "$SRC_DIR/.build/release/ChineseChess" "$APP_DIR/Contents/MacOS/ChineseChess"

# 图标
cp "$ICNS_OUTPUT" "$APP_DIR/Contents/Resources/AppIcon.icns"
rm -f "$ICNS_OUTPUT"

# 字体
cp "$BUNDLE_PATH/LXGWWenKai-Regular.ttf" "$APP_DIR/Contents/Resources/"

# 本地化 — xcstrings 放 Resources 根目录（L10n.swift 的 Bundle.main.url 查找）
cp "$BUNDLE_PATH/Localizable.xcstrings" "$APP_DIR/Contents/Resources/"

# 本地化 — .lproj 目录（String(localized:) 系统调用 + 编译后的 .strings）
# 先尝试从已有的 .app 复制 lproj
PREV_LPROJ=$(find "$PROJECT_ROOT" -name "zh-Hans.lproj" -path "*.app/*" 2>/dev/null | head -1)
if [[ -n "$PREV_LPROJ" ]]; then
    PREV_APP_RESOURCES="$(dirname "$PREV_LPROJ")"
    cp -R "$PREV_APP_RESOURCES/zh-Hans.lproj" "$APP_DIR/Contents/Resources/" 2>/dev/null || true
    cp -R "$PREV_APP_RESOURCES/en.lproj" "$APP_DIR/Contents/Resources/" 2>/dev/null || true
    echo "   ✅ 复用预编译 .lproj"
else
    # 从 xcstrings 生成 .lproj
    mkdir -p "$APP_DIR/Contents/Resources/zh-Hans.lproj"
    mkdir -p "$APP_DIR/Contents/Resources/en.lproj"
    # xcstrings 是 JSON 格式，无法直接作为 .strings 使用
    # 但 L10n.swift 已经能解析 xcstrings，所以 .lproj/.strings 是可选的 fallback
    echo "   ⚠️  无预编译 .lproj，依赖 xcstrings"
fi

# 音效
mkdir -p "$APP_DIR/Contents/Resources/Sounds"
for wav in move.wav capture.wav check.wav checkmate.wav victory.wav defeat.wav undo.wav; do
    cp "$BUNDLE_PATH/$wav" "$APP_DIR/Contents/Resources/Sounds/"
done

# 开局库
mkdir -p "$APP_DIR/Contents/Resources/OpeningBook"
cp "$BUNDLE_PATH/opening_book_v2.json" "$APP_DIR/Contents/Resources/OpeningBook/"
cp "$BUNDLE_PATH/openings.json" "$APP_DIR/Contents/Resources/OpeningBook/"

# 残局数据
mkdir -p "$APP_DIR/Contents/Resources/Puzzles"
cp "$BUNDLE_PATH/puzzles.json" "$APP_DIR/Contents/Resources/Puzzles/"
cp "$BUNDLE_PATH/puzzles-v3-backup.json" "$APP_DIR/Contents/Resources/Puzzles/" 2>/dev/null || true

echo "   ✅ .app 组装完成"
echo ""

# ============ 6. Info.plist ============
echo "📋 [6/7] 生成 Info.plist..."

cat > "$APP_DIR/Contents/Info.plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>zh-Hans</string>
	<key>CFBundleDisplayName</key>
	<string>中国象棋</string>
	<key>CFBundleExecutable</key>
	<string>ChineseChess</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIconName</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.chinesechess.app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>中国象棋</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleVersion</key>
	<string>${VERSION}</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.board-games</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSSupportsAutomaticTermination</key>
	<true/>
	<key>NSSupportsSuddenTermination</key>
	<true/>
</dict>
</plist>
PLIST_EOF

echo "   ✅ Info.plist 生成完成 (版本: $VERSION)"
echo ""

# ============ 7. 最终验证 ============
echo "✅ [7/7] 最终验证..."

ERRORS=0

# Binary
if [[ ! -f "$APP_DIR/Contents/MacOS/ChineseChess" ]]; then
    echo "   ❌ Binary 缺失"
    ERRORS=$((ERRORS + 1))
fi

# 图标
if [[ ! -f "$APP_DIR/Contents/Resources/AppIcon.icns" ]]; then
    echo "   ❌ AppIcon.icns 缺失"
    ERRORS=$((ERRORS + 1))
fi

# 本地化
if [[ ! -f "$APP_DIR/Contents/Resources/Localizable.xcstrings" ]]; then
    echo "   ❌ Localizable.xcstrings 缺失"
    ERRORS=$((ERRORS + 1))
fi

# 字体
if [[ ! -f "$APP_DIR/Contents/Resources/LXGWWenKai-Regular.ttf" ]]; then
    echo "   ❌ 字体文件缺失"
    ERRORS=$((ERRORS + 1))
fi

# Info.plist 版本号
PLIST_VERSION=$(grep -A1 "CFBundleShortVersionString" "$APP_DIR/Contents/Info.plist" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
if [[ "$PLIST_VERSION" != "$VERSION" ]]; then
    echo "   ❌ Info.plist 版本号不匹配: $PLIST_VERSION != $VERSION"
    ERRORS=$((ERRORS + 1))
fi

if [[ $ERRORS -gt 0 ]]; then
    echo "❌ 验证失败: $ERRORS 个错误"
    exit 1
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
echo "  Contents/Resources/Sounds/ ($(ls "$APP_DIR/Contents/Resources/Sounds/" | wc -l | tr -d ' ') files)"
echo "  Contents/Resources/OpeningBook/ ($(ls "$APP_DIR/Contents/Resources/OpeningBook/" | wc -l | tr -d ' ') files)"
echo "  Contents/Resources/Puzzles/ ($(ls "$APP_DIR/Contents/Resources/Puzzles/" | wc -l | tr -d ' ') files)"
if [[ -d "$APP_DIR/Contents/Resources/zh-Hans.lproj" ]]; then
    echo "  Contents/Resources/zh-Hans.lproj/"
    echo "  Contents/Resources/en.lproj/"
fi
echo "=========================================="
