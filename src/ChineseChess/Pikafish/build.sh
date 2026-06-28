#!/bin/bash
# Pikafish/build.sh — 预编译 pikafish 静态库
# Phase A: macOS/iOS 静态库嵌入
#
# NNUE 说明：pikafish 不支持编译时 NNUE 嵌入（-DNNUE_EMBEDDING_ON 是无效参数）。
# NNUE 权重文件（pikafish.nnue）作为 Bundle Resources 打包，运行时由 pikafish_api.cpp
# 通过 CFBundleCopyResourcesDirectoryURL 加载。

set -euo pipefail

# === 编译环境锁定 ===
DEPLOYMENT_TARGET_MACOS="13.0"
DEPLOYMENT_TARGET_IOS="16.0"
OPTIMIZATION="-O3"

# === 配置 ===
PIKAFISH_SRC="${1:-$HOME/DevTeam/projects/chinese-chess/ChineseChess-iOS/Pikafish/src}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

echo "=== Pikafish 预编译脚本 ==="
echo "源码路径: $PIKAFISH_SRC"
echo "输出路径: $OUTPUT_DIR"

# 验证源码路径
if [ ! -d "$PIKAFISH_SRC" ]; then
    echo "错误：pikafish 源码目录不存在"
    exit 1
fi

# 排除不需要的源文件（main.cpp 和 benchmark.cpp 是独立可执行文件入口）
SOURCES=$(find "$PIKAFISH_SRC" -name "*.cpp" | grep -v "_test.cpp" | grep -v "benchmark.cpp" | grep -v "main.cpp" | grep -v "entry_arm64.cpp" | grep -v "entry_x86.cpp")

# 记录版本信息
PIKAFISH_COMMIT=$(cd "$PIKAFISH_SRC" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
PIKAFISH_DATE=$(cd "$PIKAFISH_SRC" && git log -1 --format=%cd --date=short 2>/dev/null || echo "unknown")
CLANG_VERSION=$(clang --version | head -1)
XCODE_VERSION=$(xcodebuild -version | head -1)
SDK_VERSION=$(xcrun --show-sdk-version --sdk macosx)

# === 编译函数 ===
build_static_lib() {
    local arch=$1
    local platform=$2
    local deploy_target=$3
    local output_name=$4

    echo "Building for $platform ($arch)..."
    local build_dir="$OUTPUT_DIR/build_${output_name}"
    mkdir -p "$build_dir"

    # 编译参数
    local target="${arch}-apple-${platform}${deploy_target}"
    local common_flags="-std=c++17 ${OPTIMIZATION} -fPIC -DNDEBUG -DIS_64BIT -fexceptions"
    local platform_flags="-target ${target} -isysroot $(xcrun --sdk ${platform} --show-sdk-path 2>/dev/null || xcrun --sdk macosx --show-sdk-path)"

    # 编译所有源文件
    local obj_files=""
    for src in $SOURCES; do
        local obj="$build_dir/$(basename "${src%.cpp}").o"
        echo "  编译: $(basename $src)"
        clang++ $common_flags $platform_flags \
            -I"$PIKAFISH_SRC" \
            -I"$SCRIPT_DIR/include" \
            -c "$src" -o "$obj"
        obj_files="$obj_files $obj"
    done

    # 创建静态库
    local lib_path="$OUTPUT_DIR/lib/${output_name}/libpikafish.a"
    mkdir -p "$(dirname "$lib_path")"
    ar rcs "$lib_path" $obj_files

    # 清理中间产物
    rm -rf "$build_dir"

    echo "  生成: $lib_path"
}

# === macOS 构建 ===
echo ""
echo "=== 构建 macOS 静态库 ==="

build_static_lib arm64 macosx "$DEPLOYMENT_TARGET_MACOS" "macos-arm64"
build_static_lib x86_64 macosx "$DEPLOYMENT_TARGET_MACOS" "macos-x86_64"

# 创建 universal binary
if [ -f "$OUTPUT_DIR/lib/macos-arm64/libpikafish.a" ] && [ -f "$OUTPUT_DIR/lib/macos-x86_64/libpikafish.a" ]; then
    mkdir -p "$OUTPUT_DIR/lib/macos"
    lipo -create \
        "$OUTPUT_DIR/lib/macos-arm64/libpikafish.a" \
        "$OUTPUT_DIR/lib/macos-x86_64/libpikafish.a" \
        -output "$OUTPUT_DIR/lib/macos/libpikafish.a"
    echo "创建 universal binary: $OUTPUT_DIR/lib/macos/libpikafish.a"
fi

# === iOS 构建 ===
echo ""
echo "=== 构建 iOS 静态库 ==="

build_static_lib arm64 iphoneos "$DEPLOYMENT_TARGET_IOS" "ios"

# iOS simulator arm64 + x86_64
build_static_lib arm64 iphonesimulator "$DEPLOYMENT_TARGET_IOS" "ios-sim-arm64"
build_static_lib x86_64 iphonesimulator "$DEPLOYMENT_TARGET_IOS" "ios-sim-x86_64"

if [ -f "$OUTPUT_DIR/lib/ios-sim-arm64/libpikafish.a" ] && [ -f "$OUTPUT_DIR/lib/ios-sim-x86_64/libpikafish.a" ]; then
    mkdir -p "$OUTPUT_DIR/lib/ios-sim"
    lipo -create \
        "$OUTPUT_DIR/lib/ios-sim-arm64/libpikafish.a" \
        "$OUTPUT_DIR/lib/ios-sim-x86_64/libpikafish.a" \
        -output "$OUTPUT_DIR/lib/ios-sim/libpikafish.a"
fi

# === NNUE 文件部署提醒 ===
echo ""
echo "=== NNUE 文件部署 ==="
NNUE_FILE="${PIKAFISH_SRC}/../pikafish.nnue"
if [ -f "$NNUE_FILE" ]; then
    echo "NNUE 文件存在: $NNUE_FILE"
    echo "⚠️  确保 pikafish.nnue 被加入 App Bundle Resources（Copy Bundle Resources）"
    echo "    pikafish_api.cpp 运行时通过 CFBundleCopyResourcesDirectoryURL 加载此文件"
else
    echo "⚠️  警告：NNUE 文件不存在: $NNUE_FILE"
    echo "    没有此文件，pikafish 引擎将无法初始化"
fi

# === 验证产物 ===
echo ""
echo "=== 验证产物 ==="
for lib in "$OUTPUT_DIR"/lib/*/libpikafish.a "$OUTPUT_DIR"/lib/*/*/libpikafish.a; do
    if [ -f "$lib" ]; then
        echo "$(basename $(dirname $lib)): $(lipo -info "$lib" 2>/dev/null || file "$lib")"
    fi
done

# === 写入 VERSION ===
cat > "$OUTPUT_DIR/VERSION" <<EOF
PIKAFISH_COMMIT=${PIKAFISH_COMMIT}
PIKAFISH_DATE=${PIKAFISH_DATE}
BUILD_MACOS_VERSION=$(sw_vers -productVersion)
BUILD_XCODE_VERSION=${XCODE_VERSION}
BUILD_CLANG_VERSION=${CLANG_VERSION}
BUILD_SDK=macosx${SDK_VERSION}
BUILD_OPTIMIZATION=${OPTIMIZATION}
NNUE_LOADING=runtime_bundle_resource
MACOSX_DEPLOYMENT_TARGET=${DEPLOYMENT_TARGET_MACOS}
IOS_DEPLOYMENT_TARGET=${DEPLOYMENT_TARGET_IOS}
BUILD_DATE=$(date +%Y-%m-%d)
EOF

echo ""
echo "=== 构建完成 ==="
cat "$OUTPUT_DIR/VERSION"