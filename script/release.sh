#!/usr/bin/env bash
set -euo pipefail

readonly MODE="${1:-github}"
readonly PRODUCT_NAME="DevNotch"
readonly VERSION="1.1.1"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BUILD_ROOT="$PROJECT_ROOT/build/release"
readonly ARCHIVE_PATH="$BUILD_ROOT/DevNotch.xcarchive"
readonly ARCHIVED_APP="$ARCHIVE_PATH/Products/Applications/DevNotch.app"
readonly EXPORT_ROOT="$BUILD_ROOT/export"
readonly EXPORTED_APP="$EXPORT_ROOT/DevNotch.app"
readonly EXPORT_OPTIONS="$BUILD_ROOT/ExportOptions.plist"
readonly STAGING_ROOT="$BUILD_ROOT/dmg-root"
readonly DIST_ROOT="$PROJECT_ROOT/dist"
readonly GITHUB_DMG="$DIST_ROOT/DevNotch-${VERSION}.dmg"
readonly LOCAL_DMG="$DIST_ROOT/DevNotch-${VERSION}-local.dmg"
readonly PUBLIC_DMG="$DIST_ROOT/DevNotch-${VERSION}.dmg"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
readonly DEVELOPER_DIR

usage() {
    echo "Usage: ./script/release.sh [github|local|developer-id]" >&2
    exit 64
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: Required command not found: $1" >&2
        exit 1
    }
}

reset_directory() {
    local target="$1"
    case "$target" in
        "$BUILD_ROOT"|"$EXPORT_ROOT"|"$STAGING_ROOT") ;;
        *) echo "ERROR: Refusing to reset unexpected path: $target" >&2; exit 1 ;;
    esac
    rm -rf "$target"
    mkdir -p "$target"
}

identity_name() {
    if [[ -n "${DEVNOTCH_SIGNING_IDENTITY:-}" ]]; then
        printf '%s\n' "$DEVNOTCH_SIGNING_IDENTITY"
        return
    fi
    security find-identity -p codesigning -v \
        | sed -n 's/^[[:space:]]*[0-9][0-9]*) [A-F0-9]* "\(Developer ID Application:.*\)"$/\1/p' \
        | head -n 1
}

verify_code() {
    local app="$1"
    local claude_helper="$app/Contents/Helpers/DevNotchClaudeBridge"
    local activity_helper="$app/Contents/Helpers/DevNotchActivityBridge"
    local nowplaying_helper="$app/Contents/Helpers/DevNotchNowPlaying"

    for item in "$claude_helper" "$activity_helper" "$nowplaying_helper" "$app"; do
        [[ -e "$item" ]] || { echo "ERROR: Missing nested code: $item" >&2; exit 1; }
        [[ -x "$item" || -d "$item" ]] || { echo "ERROR: Code artifact is not executable: $item" >&2; exit 1; }
        codesign --verify --strict --verbose=2 "$item"
        local cs_info
        cs_info="$(codesign -dvvv "$item" 2>&1)"
        if [[ "$item" != "$nowplaying_helper" ]] && ! echo "$cs_info" | grep -q "flags=.*runtime"; then
            echo "ERROR: Hardened runtime flag missing on $item" >&2
            exit 1
        fi
    done

    for bin in "$claude_helper" "$activity_helper" "$nowplaying_helper" "$app/Contents/MacOS/DevNotch"; do
        if otool -L "$bin" | grep '^[[:space:]]' | grep -E "DerivedData|/Users/"; then
            echo "ERROR: Unexpected linked library path in $bin" >&2
            exit 1
        fi
    done
}

sign_local_runtime() {
    local app="$1"
    local claude_helper="$app/Contents/Helpers/DevNotchClaudeBridge"
    local activity_helper="$app/Contents/Helpers/DevNotchActivityBridge"
    local nowplaying_helper="$app/Contents/Helpers/DevNotchNowPlaying"

    codesign --force --sign - --options runtime "$claude_helper"
    codesign --force --sign - --options runtime "$activity_helper"
    codesign --force --sign - "$nowplaying_helper"
    codesign --force --sign - --options runtime \
        --entitlements "$PROJECT_ROOT/DevNotch/DevNotch.entitlements" \
        "$app"
}

create_dmg() {
    local app="$1"
    local output="$2"
    reset_directory "$STAGING_ROOT"
    /usr/bin/ditto "$app" "$STAGING_ROOT/DevNotch.app"
    ln -s /Applications "$STAGING_ROOT/Applications"
    if [[ -f "$PROJECT_ROOT/INSTALL.txt" ]]; then
        cp "$PROJECT_ROOT/INSTALL.txt" "$STAGING_ROOT/INSTALL.txt"
    else
        cat >"$STAGING_ROOT/INSTALL.txt" <<'EOF'
Dev Notch Installation

1. Drag Dev Notch into Applications.
2. Open Dev Notch from Applications.

If macOS blocks the first launch:
System Settings -> Privacy & Security -> Open Anyway.
EOF
    fi
    rm -f "$output"
    hdiutil create -volname "Dev Notch ${VERSION}" -srcfolder "$STAGING_ROOT" -ov -format UDZO "$output"
}

notarize_and_staple() {
    local artifact="$1"
    local profile="$2"
    local staple_target="${3:-$artifact}"
    local result_file="$BUILD_ROOT/notary-$(basename "$artifact").json"

    xcrun notarytool submit "$artifact" --keychain-profile "$profile" --wait --output-format json >"$result_file"
    local status
    status="$(plutil -extract status raw -o - "$result_file")"
    if [[ "$status" != "Accepted" ]]; then
        local submission_id
        submission_id="$(plutil -extract id raw -o - "$result_file" 2>/dev/null || true)"
        if [[ -n "$submission_id" ]]; then
            xcrun notarytool log "$submission_id" --keychain-profile "$profile" || true
        fi
        echo "ERROR: Notarization status: $status" >&2
        exit 1
    fi
    xcrun stapler staple "$staple_target"
    xcrun stapler validate "$staple_target"
}

[[ "$MODE" == "github" || "$MODE" == "local" || "$MODE" == "developer-id" ]] || usage
require_command xcodebuild
require_command xcrun
require_command codesign
require_command hdiutil
require_command shasum

cd "$PROJECT_ROOT"
mkdir -p "$DIST_ROOT"
reset_directory "$BUILD_ROOT"

if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate --quiet
fi
if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
    echo "==> Tests"
    xcodebuild \
        -project DevNotch.xcodeproj \
        -scheme DevNotch \
        -destination 'platform=macOS' \
        test
fi


echo "==> Archive (Release)"
if [[ "$MODE" == "github" || "$MODE" == "local" ]]; then
    xcodebuild archive \
        -project DevNotch.xcodeproj \
        -scheme DevNotch \
        -configuration Release \
        -destination 'generic/platform=macOS' \
        -derivedDataPath "$BUILD_ROOT/DerivedData" \
        -archivePath "$ARCHIVE_PATH" \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY=- \
        DEVELOPMENT_TEAM= \
        archive
else
    readonly SIGNING_IDENTITY="$(identity_name)"
    [[ "$SIGNING_IDENTITY" == Developer\ ID\ Application:* ]] || {
        echo "ERROR: Developer ID certificate unavailable." >&2
        exit 1
    }
    [[ -n "${DEVNOTCH_NOTARY_PROFILE:-}" ]] || {
        echo "ERROR: DEVNOTCH_NOTARY_PROFILE is required." >&2
        echo "Configure it with: xcrun notarytool store-credentials <profile-name>" >&2
        exit 1
    }
    [[ -n "${DEVNOTCH_DEVELOPMENT_TEAM:-}" ]] || {
        echo "ERROR: DEVNOTCH_DEVELOPMENT_TEAM is required." >&2
        exit 1
    }

    xcodebuild archive \
        -project DevNotch.xcodeproj \
        -scheme DevNotch \
        -configuration Release \
        -destination 'generic/platform=macOS' \
        -derivedDataPath "$BUILD_ROOT/DerivedData" \
        -archivePath "$ARCHIVE_PATH" \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
        DEVELOPMENT_TEAM="$DEVNOTCH_DEVELOPMENT_TEAM" \
        OTHER_CODE_SIGN_FLAGS=--timestamp \
        archive
fi

[[ -d "$ARCHIVED_APP" ]] || { echo "ERROR: Archive did not contain DevNotch.app" >&2; exit 1; }
reset_directory "$EXPORT_ROOT"
if [[ "$MODE" == "github" || "$MODE" == "local" ]]; then
    /usr/bin/ditto "$ARCHIVED_APP" "$EXPORTED_APP"
    sign_local_runtime "$EXPORTED_APP"
else
    plutil -create xml1 "$EXPORT_OPTIONS"
    plutil -insert method -string developer-id "$EXPORT_OPTIONS"
    plutil -insert teamID -string "$DEVNOTCH_DEVELOPMENT_TEAM" "$EXPORT_OPTIONS"
    plutil -insert signingStyle -string manual "$EXPORT_OPTIONS"
    plutil -insert signingCertificate -string "$SIGNING_IDENTITY" "$EXPORT_OPTIONS"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_ROOT" \
        -exportOptionsPlist "$EXPORT_OPTIONS"
fi

echo "==> Verify"
verify_code "$EXPORTED_APP"

if [[ "$MODE" == "github" ]]; then
    echo "==> Package"
    create_dmg "$EXPORTED_APP" "$GITHUB_DMG"
    echo "==> Checksum"
    shasum -a 256 "$GITHUB_DMG" >"$GITHUB_DMG.sha256"
    (cd "$DIST_ROOT" && shasum -c "$(basename "$GITHUB_DMG.sha256")")
    echo "==> GitHub Direct Distribution release ready"
    echo "DMG: $GITHUB_DMG"
    echo "SHA-256: $GITHUB_DMG.sha256"
    echo "Note: Dev Notch is distributed directly via GitHub without an Apple Developer ID."
    echo "Users may need to allow launch on first run: System Settings -> Privacy & Security -> Open Anyway."
    exit 0
fi

if [[ "$MODE" == "local" ]]; then
    echo "==> Package"
    create_dmg "$EXPORTED_APP" "$LOCAL_DMG"
    echo "==> Checksum"
    shasum -a 256 "$LOCAL_DMG" >"$LOCAL_DMG.sha256"
    (cd "$DIST_ROOT" && shasum -c "$(basename "$LOCAL_DMG.sha256")")
    echo "WARNING:"
    echo "This build is not Developer ID signed/notarized."
    echo "Local artifact: $LOCAL_DMG"
    exit 0
fi

echo "==> Notarize app"
readonly APP_ZIP="$BUILD_ROOT/DevNotch-${VERSION}.zip"
/usr/bin/ditto -c -k --keepParent "$EXPORTED_APP" "$APP_ZIP"
notarize_and_staple "$APP_ZIP" "$DEVNOTCH_NOTARY_PROFILE" "$EXPORTED_APP"

echo "==> Package"
create_dmg "$EXPORTED_APP" "$PUBLIC_DMG"

echo "==> Notarize DMG"
notarize_and_staple "$PUBLIC_DMG" "$DEVNOTCH_NOTARY_PROFILE"

echo "==> Gatekeeper"
spctl -a -vv --type execute "$EXPORTED_APP"
spctl -a -vv --type open "$PUBLIC_DMG"

echo "==> Checksum"
shasum -a 256 "$PUBLIC_DMG" >"$PUBLIC_DMG.sha256"
echo "Release candidate ready: $PUBLIC_DMG"
