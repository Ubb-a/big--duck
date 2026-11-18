#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_REPO="${1:-$FLUTTER_ROOT/rust}"
JNI_OUT="$FLUTTER_ROOT/android/app/src/main/jniLibs"

if [ -z "${ANDROID_NDK_HOME:-}" ]; then
  SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [ -n "$SDK_ROOT" ] && [ -d "$SDK_ROOT/ndk" ]; then
    ANDROID_NDK_HOME="$(find "$SDK_ROOT/ndk" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1 || true)"
    export ANDROID_NDK_HOME
  fi
fi

if [ -z "${ANDROID_NDK_HOME:-}" ] || [ ! -d "$ANDROID_NDK_HOME" ]; then
  echo "ERROR: Android NDK not found. Set ANDROID_NDK_HOME or install NDK under ANDROID_HOME/ndk."
  exit 1
fi

echo "Using ANDROID_NDK_HOME=$ANDROID_NDK_HOME"
mkdir -p "$JNI_OUT"
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android

pushd "$RUST_REPO" >/dev/null
cargo ndk \
  -t arm64-v8a \
  -t armeabi-v7a \
  -t x86_64 \
  -o "$JNI_OUT" \
  build --release -p teledrive-mobile-bridge
popd >/dev/null

echo "Built Android Rust libraries into $JNI_OUT"
