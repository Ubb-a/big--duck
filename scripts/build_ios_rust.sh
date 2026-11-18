#!/usr/bin/env bash
set -euo pipefail

# Builds teledrive-mobile-bridge from the vendored rust/ workspace for iOS.
# Usage:
#   ./scripts/build_ios_rust.sh                # builds device + simulator & xcframework
#   ./scripts/build_ios_rust.sh --device-only  # builds aarch64-apple-ios staticlib only (for IPA CI)
#   ./scripts/build_ios_rust.sh --sim-only     # builds aarch64-apple-ios-sim staticlib only
if [ "$(uname -s)" != "Darwin" ]; then
  echo "iOS Rust build requires macOS with Xcode."
  exit 1
fi

MODE="all"
if [ "${1:-}" = "--device-only" ] || [ "${1:-}" = "--sim-only" ]; then
  MODE="$1"
  shift
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_REPO="${1:-$FLUTTER_ROOT/rust}"
HEADERS_DIR="$FLUTTER_ROOT/ios/Runner/include"
FRAMEWORKS_DIR="$FLUTTER_ROOT/ios/Frameworks"
STATIC_OUT="$FRAMEWORKS_DIR/libteledrive_mobile_bridge.a"
XCFRAMEWORK_OUT="$FRAMEWORKS_DIR/BigDuckCore.xcframework"

mkdir -p "$HEADERS_DIR" "$FRAMEWORKS_DIR"

if [ "$MODE" = "--device-only" ]; then
  rustup target add aarch64-apple-ios
  pushd "$RUST_REPO" >/dev/null
  IPHONEOS_DEPLOYMENT_TARGET=15.0 cargo build --release --target aarch64-apple-ios -p teledrive-mobile-bridge
  popd >/dev/null
  cp -f "$RUST_REPO/target/aarch64-apple-ios/release/libteledrive_mobile_bridge.a" "$STATIC_OUT"
  echo "Built iOS device static library at $STATIC_OUT"
  exit 0
fi

if [ "$MODE" = "--sim-only" ]; then
  rustup target add aarch64-apple-ios-sim
  pushd "$RUST_REPO" >/dev/null
  IPHONEOS_DEPLOYMENT_TARGET=15.0 cargo build --release --target aarch64-apple-ios-sim -p teledrive-mobile-bridge
  popd >/dev/null
  cp -f "$RUST_REPO/target/aarch64-apple-ios-sim/release/libteledrive_mobile_bridge.a" "$STATIC_OUT"
  echo "Built iOS simulator static library at $STATIC_OUT"
  exit 0
fi

rustup target add aarch64-apple-ios aarch64-apple-ios-sim

pushd "$RUST_REPO" >/dev/null
IPHONEOS_DEPLOYMENT_TARGET=15.0 cargo build --release --target aarch64-apple-ios -p teledrive-mobile-bridge
IPHONEOS_DEPLOYMENT_TARGET=15.0 cargo build --release --target aarch64-apple-ios-sim -p teledrive-mobile-bridge
popd >/dev/null

DEVICE_LIB="$RUST_REPO/target/aarch64-apple-ios/release/libteledrive_mobile_bridge.a"
SIM_LIB="$RUST_REPO/target/aarch64-apple-ios-sim/release/libteledrive_mobile_bridge.a"

cp -f "$DEVICE_LIB" "$STATIC_OUT"
rm -rf "$XCFRAMEWORK_OUT"
xcodebuild -create-xcframework \
  -library "$DEVICE_LIB" -headers "$HEADERS_DIR" \
  -library "$SIM_LIB" -headers "$HEADERS_DIR" \
  -output "$XCFRAMEWORK_OUT"

echo "Created $XCFRAMEWORK_OUT and updated $STATIC_OUT"
