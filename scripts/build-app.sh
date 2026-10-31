#!/bin/bash
set -euo pipefail

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
