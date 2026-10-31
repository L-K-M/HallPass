#!/bin/bash
# Builds dist/HallPass.app from the SwiftPM package, writes its icon, ad-hoc
# signs the bundle and verifies the signature.
#
#   scripts/build-app.sh [--debug] [--universal]
#
# --debug builds the Debug configuration (scripts/build.sh --debug reaches this
# through lkm-build's swiftpm kind). --universal builds a fat arm64+x86_64
# binary; the default is the host architecture, which is faster for local runs.
# HALLPASS_BUILD_DIR and/or HALLPASS_OUTPUT_DIR override the build and output
# directories.
set -euo pipefail

MINIMUM_SDK_MAJOR=26
if [[ "$(uname -s)" != "Darwin" ]]; then
    printf 'HallPass requires macOS %s and Xcode %s or later.\n' "$MINIMUM_SDK_MAJOR" "$MINIMUM_SDK_MAJOR" >&2
    exit 1
fi
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
if (( ${SDK_VERSION%%.*} < MINIMUM_SDK_MAJOR )); then
    printf 'Select Xcode %s or later with xcode-select before building HallPass.\n' "$MINIMUM_SDK_MAJOR" >&2
    exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${HALLPASS_BUILD_DIR:-$PROJECT_ROOT/.build}"
OUTPUT_DIR="${HALLPASS_OUTPUT_DIR:-$PROJECT_ROOT/dist}"
APP="$OUTPUT_DIR/HallPass.app"

CONFIG=release
ARCH_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --debug) CONFIG=debug ;;
    --universal) ARCH_ARGS=(--arch arm64 --arch x86_64) ;;
    *) echo "error: unknown option '$arg' (expected --debug or --universal)" >&2; exit 2 ;;
  esac
done

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"
export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_DIR/module-cache"

cd "$PROJECT_ROOT"
swift build -c "$CONFIG" --scratch-path "$BUILD_DIR" --cache-path "$BUILD_DIR/package-cache" --disable-sandbox ${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"}
BIN_DIR="$(swift build -c "$CONFIG" --scratch-path "$BUILD_DIR" --cache-path "$BUILD_DIR/package-cache" --disable-sandbox --show-bin-path ${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"})"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/HallPass" "$APP/Contents/MacOS/HallPass"
cp "$PROJECT_ROOT/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

swift "$PROJECT_ROOT/scripts/make-icon.swift" "$PROJECT_ROOT/assets/HallPass-icon.png" "$BUILD_DIR/HallPass.iconset"
/usr/bin/iconutil -c icns "$BUILD_DIR/HallPass.iconset" -o "$APP/Contents/Resources/HallPass.icns"
/usr/bin/codesign --force --sign - "$APP"
/usr/bin/codesign --verify --strict "$APP"
printf '\nHallPass ist bereit: %s\n' "$APP"
