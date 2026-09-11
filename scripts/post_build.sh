#!/bin/bash
# Post-build script for V8Ray
# This script runs after Flutter build to download Xray Core to the bundle directory

set -e

echo "=== V8Ray Post-Build Script ==="

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Project root: $PROJECT_ROOT"

# 获取构建模式
BUILD_MODE="${1:-debug}"

echo "Build mode: $BUILD_MODE"

# 下载 Xray Core 到构建输出目录
echo ""
echo "Downloading Xray Core to bundle directory..."
cd "$PROJECT_ROOT/scripts"

# 检查是否需要强制更新
FORCE_FLAG=""
if [ "$2" == "--force-xray" ]; then
    FORCE_FLAG="--force"
    echo "Force update Xray Core enabled"
fi

dart download_xray.dart --build-mode "$BUILD_MODE" $FORCE_FLAG

# macOS：Flutter 不会自动把 Rust dylib 打进 .app，需手动复制
if [ "$(uname -s)" = "Darwin" ]; then
    echo ""
    echo "Copying libv8ray_core.dylib into the macOS app bundle..."
    if [ "$BUILD_MODE" = "release" ]; then
        APP_MACOS="$PROJECT_ROOT/app/build/macos/Build/Products/Release/v8ray.app/Contents/MacOS"
        MODE_DIR="release"
    else
        APP_MACOS="$PROJECT_ROOT/app/build/macos/Build/Products/Debug/v8ray.app/Contents/MacOS"
        MODE_DIR="debug"
    fi

    RUST_LIB=""
    for candidate in \
        "$PROJECT_ROOT/core/target/aarch64-apple-darwin/${MODE_DIR}/libv8ray_core.dylib" \
        "$PROJECT_ROOT/core/target/x86_64-apple-darwin/${MODE_DIR}/libv8ray_core.dylib" \
        "$PROJECT_ROOT/core/target/${MODE_DIR}/libv8ray_core.dylib"
    do
        if [ -f "$candidate" ]; then
            RUST_LIB="$candidate"
            break
        fi
    done

    if [ ! -f "$RUST_LIB" ]; then
        echo "ERROR: Rust library not found: $RUST_LIB"
        exit 1
    fi
    if [ ! -d "$APP_MACOS" ]; then
        echo "ERROR: App bundle MacOS directory not found: $APP_MACOS"
        exit 1
    fi

    cp "$RUST_LIB" "$APP_MACOS/"
    echo "✓ Copied $(basename "$RUST_LIB") to $APP_MACOS"
    ls -la "$APP_MACOS"
fi

echo ""
echo "✓ Post-build completed successfully"

