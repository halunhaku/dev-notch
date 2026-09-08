#!/usr/bin/env bash
set -euo pipefail

# Ensure DEVELOPER_DIR points to Xcode toolchain
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "==> [1/4] Stopping existing DevNotch process..."
killall DevNotch 2>/dev/null || true
sleep 0.5

echo "==> [2/4] Regenerating Xcode project if needed..."
if command -v xcodegen &>/dev/null; then
    xcodegen generate --quiet
fi

echo "==> [3/4] Building DevNotch, DevNotchClaudeBridge, and DevNotchActivityBridge with xcodebuild..."
xcodebuild \
  -project DevNotch.xcodeproj \
  -scheme DevNotch \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE="Manual" \
  build >/dev/null

xcodebuild \
  -project DevNotch.xcodeproj \
  -scheme DevNotchClaudeBridge \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE="Manual" \
  build >/dev/null

xcodebuild \
  -project DevNotch.xcodeproj \
  -scheme DevNotchActivityBridge \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE="Manual" \
  build >/dev/null

# Deploy bridge binaries for local hooks
APP_SUPPORT_DIR="$HOME/Library/Application Support/DevNotch"
mkdir -p "$APP_SUPPORT_DIR/Claude" "$APP_SUPPORT_DIR/Activities"

CLAUDE_BRIDGE_SRC="build/DerivedData/Build/Products/Debug/DevNotchClaudeBridge"
if [[ -f "$CLAUDE_BRIDGE_SRC" ]]; then
    cp -f "$CLAUDE_BRIDGE_SRC" "$APP_SUPPORT_DIR/Claude/DevNotchClaudeBridge"
    chmod +x "$APP_SUPPORT_DIR/Claude/DevNotchClaudeBridge"
fi

ACTIVITY_BRIDGE_SRC="build/DerivedData/Build/Products/Debug/DevNotchActivityBridge"
if [[ -f "$ACTIVITY_BRIDGE_SRC" ]]; then
    cp -f "$ACTIVITY_BRIDGE_SRC" "$APP_SUPPORT_DIR/Activities/DevNotchActivityBridge"
    chmod +x "$APP_SUPPORT_DIR/Activities/DevNotchActivityBridge"
    cp -f "$ACTIVITY_BRIDGE_SRC" "$APP_SUPPORT_DIR/Claude/DevNotchActivityBridge" 2>/dev/null || true
fi

APP_PATH="build/DerivedData/Build/Products/Debug/DevNotch.app"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: DevNotch.app not found at $APP_PATH" >&2
    exit 1
fi

echo "==> [4/4] Launching DevNotch ($APP_PATH)..."
open "$APP_PATH"

sleep 0.8
if pgrep -x DevNotch >/dev/null; then
    PID=$(pgrep -x DevNotch | head -n 1)
    echo " DevNotch is running successfully! (PID: $PID)"
else
    echo "Warning: DevNotch process not detected immediately via pgrep."
fi
