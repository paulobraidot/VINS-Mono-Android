#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
THIRD_PARTY_DIR="$ROOT_DIR/app/libs/VINS-Mobile-master/VINS_ThirdPartyLib"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "=== Setting up ThirdParty Dependencies in $THIRD_PARTY_DIR ==="

# 1. OpenCV SDK
if [ ! -d "$THIRD_PARTY_DIR/opencv-4.5.0-android-sdk/OpenCV-android-sdk" ]; then
    echo "Downloading OpenCV 4.5.0 Android SDK..."
    curl -L -o "$TMP_DIR/opencv.zip" https://github.com/opencv/opencv/releases/download/4.5.0/opencv-4.5.0-android-sdk.zip
    mkdir -p "$THIRD_PARTY_DIR/opencv-4.5.0-android-sdk"
    unzip -q "$TMP_DIR/opencv.zip" -d "$THIRD_PARTY_DIR/opencv-4.5.0-android-sdk/"
fi

# 2. Boost
if [ ! -d "$THIRD_PARTY_DIR/boost_1_63_0" ]; then
    echo "Downloading Boost 1.63.0..."
    curl -L -o "$TMP_DIR/boost.tar.gz" https://archives.boost.io/release/1.63.0/source/boost_1_63_0.tar.gz
    tar -xzf "$TMP_DIR/boost.tar.gz" -C "$THIRD_PARTY_DIR/"
fi

# 3. Eigen
if [ ! -d "$THIRD_PARTY_DIR/eigen3" ]; then
    echo "Downloading Eigen 3.3.9..."
    curl -L -o "$TMP_DIR/eigen.tar.gz" https://gitlab.com/libeigen/eigen/-/archive/3.3.9/eigen-3.3.9.tar.gz
    mkdir -p "$THIRD_PARTY_DIR/eigen3"
    tar -xzf "$TMP_DIR/eigen.tar.gz" -C "$TMP_DIR/"
    mv "$TMP_DIR"/eigen-3.3.9/* "$THIRD_PARTY_DIR/eigen3/"
fi

# 4. Ceres Solver
if [ ! -d "$THIRD_PARTY_DIR/ceres-solver" ]; then
    echo "Downloading Ceres Solver 1.14.0..."
    curl -L -o "$TMP_DIR/ceres.tar.gz" https://github.com/ceres-solver/ceres-solver/archive/refs/tags/1.14.0.tar.gz
    mkdir -p "$THIRD_PARTY_DIR/ceres-solver"
    tar -xzf "$TMP_DIR/ceres.tar.gz" -C "$TMP_DIR/"
    mv "$TMP_DIR"/ceres-solver-1.14.0/* "$THIRD_PARTY_DIR/ceres-solver/"
fi

# Patch Ceres Application.mk & Android.mk for arm64-v8a + frtti
echo "Patching Ceres Solver build files..."
sed -i 's/-fno-rtti/-frtti/g' "$THIRD_PARTY_DIR/ceres-solver/jni/Application.mk"
sed -i 's/APP_ABI := armeabi-v7a/APP_ABI := arm64-v8a/g' "$THIRD_PARTY_DIR/ceres-solver/jni/Application.mk"
if ! grep -q "thread_token_provider.cc" "$THIRD_PARTY_DIR/ceres-solver/jni/Android.mk"; then
    sed -i '/subset_preconditioner.cc/a \                   $(CERES_SRC_PATH)/thread_token_provider.cc \\' "$THIRD_PARTY_DIR/ceres-solver/jni/Android.mk"
fi

# Build Ceres Solver using ndk-build
echo "Building Ceres Solver..."
NDK_BUILD_CMD=""
if [ -n "$ANDROID_NDK_HOME" ] && [ -f "$ANDROID_NDK_HOME/ndk-build" ]; then
    NDK_BUILD_CMD="$ANDROID_NDK_HOME/ndk-build"
elif [ -n "$ANDROID_HOME" ] && [ -f "$ANDROID_HOME/ndk/22.0.7026061/ndk-build" ]; then
    NDK_BUILD_CMD="$ANDROID_HOME/ndk/22.0.7026061/ndk-build"
elif [ -n "$ANDROID_NDK" ] && [ -f "$ANDROID_NDK/ndk-build" ]; then
    NDK_BUILD_CMD="$ANDROID_NDK/ndk-build"
else
    NDK_BUILD_CMD="$(which ndk-build || true)"
fi

if [ -z "$NDK_BUILD_CMD" ]; then
    echo "Error: ndk-build not found!"
    exit 1
fi

echo "Using NDK build at: $NDK_BUILD_CMD"
cd "$THIRD_PARTY_DIR/ceres-solver/jni"
EIGEN_PATH="$THIRD_PARTY_DIR/eigen3" "$NDK_BUILD_CMD" -B APP_ABI=arm64-v8a -j$(nproc)

echo "=== Dependencies setup complete! ==="
