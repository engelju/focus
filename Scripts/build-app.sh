#!/bin/bash
# Builds Focus.app into dist/, ad-hoc signs it, and installs it to
# /Applications (so Spotlight and Launchpad find it).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${CONFIG:-release}"
APP="$ROOT/dist/Focus.app"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Focus"

# --- icon (cached) -----------------------------------------------------------
if [ ! -f "$ROOT/Bundle/AppIcon.icns" ]; then
    echo "==> rendering app icon"
    WORK="$(mktemp -d)"
    swift "$ROOT/Scripts/make-icon.swift" "$WORK/icon.png" >/dev/null
    ICONSET="$WORK/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size "$WORK/icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        double=$((size * 2))
        sips -z $double $double "$WORK/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$ROOT/Bundle/AppIcon.icns"
    rm -rf "$WORK"
fi

# --- bundle ------------------------------------------------------------------
echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Focus"
cp "$ROOT/Bundle/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Bundle/Focus.sdef" "$APP/Contents/Resources/Focus.sdef"
cp "$ROOT/Bundle/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> ad-hoc signing"
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 \
    || codesign --force --sign - "$APP"

# --- install -----------------------------------------------------------------
# Moved rather than copied, so Spotlight doesn't index two Focus apps. Only
# replaces an existing app if it's ours.
INSTALLED=/Applications/Focus.app
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$ROOT/Bundle/Info.plist")
if [ -e "$INSTALLED" ]; then
    EXISTING_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INSTALLED/Contents/Info.plist" 2>/dev/null || true)
    if [ "$EXISTING_ID" != "$BUNDLE_ID" ]; then
        echo "$INSTALLED exists but isn't Focus ($EXISTING_ID); leaving it alone. Built $APP" >&2
        exit 1
    fi
    rm -rf "$INSTALLED"
fi
mv "$APP" "$INSTALLED"

echo "==> installed $INSTALLED"
if pgrep -xq Focus; then
    echo "Focus is running — quit and relaunch it (or use 'make run') to use the new build."
fi
