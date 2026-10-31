#!/bin/bash
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
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"
export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_DIR/module-cache"

cd "$PROJECT_ROOT"
swift build -c release --scratch-path "$BUILD_DIR" --cache-path "$BUILD_DIR/package-cache" --disable-sandbox
BIN_DIR="$(swift build -c release --scratch-path "$BUILD_DIR" --cache-path "$BUILD_DIR/package-cache" --disable-sandbox --show-bin-path)"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/HallPass" "$APP/Contents/MacOS/HallPass"
cp "$PROJECT_ROOT/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

swift "$PROJECT_ROOT/scripts/make-icon.swift" "$PROJECT_ROOT/assets/HallPass-icon.png" "$BUILD_DIR/HallPass.iconset"
/usr/bin/iconutil -c icns "$BUILD_DIR/HallPass.iconset" -o "$APP/Contents/Resources/HallPass.icns"
/usr/bin/codesign --force --sign - "$APP"
/usr/bin/codesign --verify --strict "$APP"
printf '\nHallPass ist bereit: %s\n' "$APP"
