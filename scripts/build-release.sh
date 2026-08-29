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

# ============ 并发构建锁 ============
# 避免 Xcode build DB 锁冲突：同一时间只允许一个 build-release.sh 运行
# macOS 没有 flock，使用 mkdir 作为锁（原子操作）
LOCK_DIR="/tmp/chinesechess-build-release.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "❌ 另一个 build-release.sh 正在运行（build DB 锁冲突防护）"
    echo "   如需强制释放: rm -rf $LOCK_DIR"
    exit 1
fi
trap 'rm -rf "$LOCK_DIR"' EXIT  # 脚本退出时自动释放锁
echo "🔒 已获取构建锁"

# ============ 参数校验 ============
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "❌ 用法: bash scripts/build-release.sh <版本号>"
    echo "   例如: bash scripts/build-release.sh 3.5.0"
    exit 1
fi

# ============ 路径定义 ============
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# 去掉参数可能带的 v 前缀，避免输出 vv3.5.0
VERSION_NUM="${VERSION#v}"
APP_NAME="中国象棋-v${VERSION_NUM}.app"
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
    ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR/Release" 2>&1 | tail -5

if [[ ! -d "$XC_APP" ]]; then
    echo "❌ 构建失败：ChineseChess.app 不存在"
    exit 1
fi
echo "   ✅ 构建成功"

# Bundle ID 校验
ACTUAL_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$XC_APP/Contents/Info.plist")
EXPECTED_ID="com.chinesechess.app"
if [ "$ACTUAL_ID" != "$EXPECTED_ID" ]; then
    echo "❌ Bundle ID mismatch: expected $EXPECTED_ID, got $ACTUAL_ID"
    exit 1
fi
echo "   ✅ Bundle ID 校验通过 ($EXPECTED_ID)"
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
    echo "⚠️  iconutil 生成失败，尝试使用源码预编译 icns..."
    SOURCE_ICNS="$ICONSET_DIR/AppIcon.icns"
    if [[ -f "$SOURCE_ICNS" ]]; then
        cp "$SOURCE_ICNS" "$ICNS_OUTPUT"
        echo "   ✅ 使用源码 appiconset/AppIcon.icns"
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
    -c "Set :CFBundleShortVersionString $VERSION_NUM" \
    -c "Set :CFBundleVersion $VERSION_NUM" \
    -c "Set :CFBundleDisplayName 中国象棋" \
    "$APP_DIR/Contents/Info.plist" 2>/dev/null
echo "   ✅ 版本号已更新为 $VERSION_NUM"

echo ""

# ============ 5.5. 产物 manifest 对账（v6.3 Step 4：L4 消费，与 L1/E1 同源） ============
echo "🧾 [5.5/6] 产物对 asset-manifest.json 对账（L4）..."
MANIFEST="$PROJECT_ROOT/src/ChineseChess/Resources/asset-manifest.json"
if [[ ! -f "$MANIFEST" ]]; then
    echo "❌ asset-manifest.json 不存在，无法对账"
    exit 1
fi
if ! MANIFEST="$MANIFEST" APP="$APP_DIR" python3 - <<'PYEOF'
import glob, hashlib, json, os, sys
m = json.load(open(os.environ["MANIFEST"]))
app = os.environ["APP"]
bad = 0
for a in m.get("assets", []):
    if a.get("repoOnly"):
        continue  # xcstrings 等：v6.2 起有意不入包，仅 L1 源侧对账
    p = os.path.join(app, a["bundlePath"])
    if not os.path.isfile(p):
        print(f"   ❌ [{a['name']}] 产物缺失: {a['bundlePath']}"); bad += 1; continue
    sz = os.path.getsize(p)
    if a.get("generated"):
        # 生成件（icns）：iconutil 产物 hash 不稳定，只做存在 + 体量 sanity
        if sz < 500_000:
            print(f"   ❌ [{a['name']}] 体量异常: {sz} bytes（疑空/坏 icon）"); bad += 1
        continue
    if sz != a["bytes"]:
        print(f"   ❌ [{a['name']}] 大小不符: bundle={sz} manifest={a['bytes']}"); bad += 1; continue
    h = hashlib.sha256(open(p, "rb").read()).hexdigest()
    if h != a["sha256"]:
        print(f"   ❌ [{a['name']}] sha256 不符: bundle={h[:16]}… manifest={a['sha256'][:16]}…"); bad += 1
for d in m.get("dirs", []):
    p = os.path.join(app, d["bundlePath"])
    if not os.path.isdir(p):
        print(f"   ❌ [{d['name']}] 产物目录缺失: {d['bundlePath']}"); bad += 1; continue
    g = d.get("bundleGlob")
    n = len(glob.glob(os.path.join(p, g))) if g else len([f for f in os.listdir(p) if not f.startswith(".")])
    if n == 0:
        print(f"   ❌ [{d['name']}] 0 files（PKG-1 形态：拷贝落空/资源未入包，显式 fail 不静默通过）"); bad += 1
    elif n < d["minFiles"]:
        print(f"   ❌ [{d['name']}] 文件数 {n} < minFiles {d['minFiles']}"); bad += 1
sys.exit(1 if bad else 0)
PYEOF
then
    echo "❌ 产物 manifest 对账失败（上方 ❌ 条目）——坏包阻断，不进入签名/分发"
    exit 1
fi
echo "   ✅ manifest 对账通过（assets+dirs 全量）"
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

# ============ 7. Git Tag ============
echo ""
echo "📌 [7/6] Git tag..."

# 检查 working tree
if git status --short | grep -q .; then
    echo "   ⚠️  working tree 有未提交文件，tag 可能不完整"
fi

# 检查 tag 是否已存在
if git tag -l "v$VERSION_NUM" | grep -q .; then
    echo "   ⏩  git tag v$VERSION_NUM 已存在，跳过"
else
    if git tag "v$VERSION_NUM" 2>/dev/null; then
        echo "   📌 已创建 git tag v$VERSION_NUM，记得推送到远程（git push origin v$VERSION_NUM）"
    else
        echo "   ⚠️  git tag 创建失败，但不阻塞打包"
    fi
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
# 摘要与 manifest 同源展示（PKG-1）：0 files 类异常已在 [5.5] 显式 fail，不静默通过
OB_N=$(ls "$APP_DIR/Contents/Resources/OpeningBook/" 2>/dev/null | wc -l | tr -d ' ')
PZ_N=$(ls "$APP_DIR/Contents/Resources/Puzzles/" 2>/dev/null | wc -l | tr -d ' ')
echo "  Contents/Resources/OpeningBook/ ($OB_N files)"
echo "  Contents/Resources/Puzzles/ ($PZ_N files)"
echo "=========================================="

open "$PROJECT_ROOT"
