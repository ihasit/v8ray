#!/bin/bash
# Pre-build script for V8Ray
# This script runs before Flutter build to prepare dependencies

set -e

echo "=== V8Ray Pre-Build Script ==="

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Project root: $PROJECT_ROOT"

# 1. 检查并生成 Flutter Rust Bridge 代码（如果需要）
echo ""
echo "Step 1: Checking Flutter Rust Bridge code..."
if [ ! -f "$PROJECT_ROOT/core/src/frb_generated.rs" ] || [ ! -f "$PROJECT_ROOT/app/lib/core/ffi/frb_generated.dart" ]; then
    echo "FRB generated code not found, generating..."
    cd "$PROJECT_ROOT"
    flutter_rust_bridge_codegen generate
    echo "✓ FRB code generated"
else
    echo "✓ FRB code already exists"
fi

# 2. 构建 Rust Core (生成下载信息)
echo ""
echo "Step 2: Building Rust Core..."
cd "$PROJECT_ROOT/core"

# 根据构建类型选择 profile
BUILD_MODE="${1:-debug}"
RUST_TARGET="${2:-}"

TARGET_ARGS=()
if [ -n "$RUST_TARGET" ]; then
    echo "Rust target: $RUST_TARGET"
    rustup target add "$RUST_TARGET"
    TARGET_ARGS=(--target "$RUST_TARGET")
fi

if [ "$BUILD_MODE" == "release" ]; then
    echo "Building in release mode..."
    cargo build --release --lib "${TARGET_ARGS[@]}"
else
    echo "Building in debug mode..."
    cargo build --lib "${TARGET_ARGS[@]}"
fi

# --target 产物在 target/<triple>/，复制到 target/{debug,release} 供 Flutter / post_build 使用
if [ -n "$RUST_TARGET" ]; then
    MODE_DIR="debug"
    if [ "$BUILD_MODE" = "release" ]; then
        MODE_DIR="release"
    fi
    SRC_DIR="target/${RUST_TARGET}/${MODE_DIR}"
    DST_DIR="target/${MODE_DIR}"
    mkdir -p "$DST_DIR"
    if ls "$SRC_DIR"/libv8ray_core.* >/dev/null 2>&1; then
        cp -f "$SRC_DIR"/libv8ray_core.* "$DST_DIR/"
        echo "✓ Copied Rust library from $SRC_DIR to $DST_DIR"
    elif ls "$SRC_DIR"/v8ray_core.* >/dev/null 2>&1; then
        cp -f "$SRC_DIR"/v8ray_core.* "$DST_DIR/"
        echo "✓ Copied Rust library from $SRC_DIR to $DST_DIR"
    else
        echo "ERROR: Rust library not found in $SRC_DIR"
        ls -la "$SRC_DIR" || true
        exit 1
    fi
fi

echo ""
echo "✓ Pre-build completed successfully"
echo ""
echo "Note: Xray Core will be downloaded after Flutter build to the bundle directory"

