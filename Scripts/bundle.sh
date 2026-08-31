#!/usr/bin/env bash
# Assemble Vellbar.app from the SwiftPM build product.
#
#   ./Scripts/bundle.sh              debug build, ad-hoc signed
#   ./Scripts/bundle.sh --release    release build
#   ./Scripts/bundle.sh --reset-tcc  also clear the Accessibility grant
#
# Set VELLSNAP_SIGN_IDENTITY to a stable signing identity to stop macOS treating
# every rebuild as a brand-new app (see the TCC note at the bottom).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="debug"
RESET_TCC=0
BUNDLE_ID="com.vellund.Vellbar"
APP_NAME="Vellbar"
VERSION="0.1.0"

for arg in "$@"; do
  case "$arg" in
    --release)   CONFIG="release" ;;
    --reset-tcc) RESET_TCC=1 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

# Release builds are universal. A release that only runs on Apple silicon
# would strand every Intel Mac, and the download page promises both.
# macOS ships bash 3.2, where expanding an empty array under `set -u` is an
# error — so build the flags as a plain string rather than an array.
ARCH_FLAGS=""
LABEL="$CONFIG"
if [[ "$CONFIG" == "release" ]]; then
  ARCH_FLAGS="--arch arm64 --arch x86_64"
  LABEL="$CONFIG, universal"
fi

echo "==> Building ($LABEL)"
# Unquoted on purpose: these are separate arguments, not one.
swift build -c "$CONFIG" --package-path "$ROOT" $ARCH_FLAGS
BIN="$(swift build -c "$CONFIG" --package-path "$ROOT" $ARCH_FLAGS --show-bin-path)/$APP_NAME"

APP="$ROOT/build/$APP_NAME.app"
echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

if [[ -f "$ROOT/Resources/$APP_NAME.icns" ]]; then
  cp "$ROOT/Resources/$APP_NAME.icns" "$APP/Contents/Resources/"
else
  echo "    no icon found — run: swift Scripts/make-icon.swift"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                 <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>          <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>           <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>           <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>          <string>APPL</string>
    <key>CFBundleShortVersionString</key>   <string>$VERSION</string>
    <key>CFBundleVersion</key>              <string>1</string>
    <key>CFBundleIconFile</key>             <string>$APP_NAME</string>
    <key>LSMinimumSystemVersion</key>       <string>14.0</string>
    <!-- Menu bar agent: no Dock icon, no app switcher entry. -->
    <key>LSUIElement</key>                  <true/>
    <key>NSHumanReadableCopyright</key>     <string>Vellund</string>
    <!-- Shown in the Screen Recording prompt. macOS draws every status item
         inside one system process and exposes no API for their images, so
         photographing the menu bar is the only way to show real icons. -->
    <key>NSScreenCaptureUsageDescription</key>
    <string>Vellbar photographs a single strip of your menu bar so it can show the real icons in its list. Nothing is written to disk or sent anywhere.</string>
</dict>
</plist>
PLIST

# Pick a signing identity. A real certificate matters more than it sounds:
# it makes the *designated requirement* cert-based rather than hash-based, so
# the Accessibility grant survives every rebuild. Ad-hoc signing does not.
if [[ -z "${VELLSNAP_SIGN_IDENTITY:-}" ]]; then
  # Prefer a distribution cert, fall back to a development one.
  for pattern in "Developer ID Application" "Apple Development" "Mac Developer"; do
    # `|| true` matters: under `set -e` + `pipefail`, a grep that finds
    # nothing would abort the whole script rather than trying the next pattern.
    found=$(security find-identity -v -p codesigning 2>/dev/null \
            | grep -m1 "$pattern" | sed -E 's/.*"(.*)".*/\1/' || true)
    if [[ -n "$found" ]]; then
      VELLSNAP_SIGN_IDENTITY="$found"
      echo "==> Auto-selected signing identity: $VELLSNAP_SIGN_IDENTITY"
      break
    fi
  done
fi

echo "==> Signing"
if [[ -n "${VELLSNAP_SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp \
           --sign "$VELLSNAP_SIGN_IDENTITY" "$APP"
  echo "    signed as: $VELLSNAP_SIGN_IDENTITY"
else
  codesign --force --sign - "$APP"
  echo "    ad-hoc signed (see TCC note below)"
fi

if [[ $RESET_TCC -eq 1 ]]; then
  echo "==> Resetting Accessibility grant for $BUNDLE_ID"
  tccutil reset Accessibility "$BUNDLE_ID" || true
fi

echo
echo "Built: $APP"
echo "    architectures: $(lipo -archs "$APP/Contents/MacOS/$APP_NAME")"
codesign -dv "$APP" 2>&1 | sed 's/^/    /'

cat <<'NOTE'

TCC note
--------
macOS identifies an app for permissions by its code signature. This script now
auto-selects a real signing identity from your keychain, which makes the
designated requirement certificate-based — so the Accessibility grant survives
rebuilds and you only ever grant it once.

If it falls back to ad-hoc (no identity found), every rebuild looks like a new
app and the grant silently stops working — windows just refuse to move, with no
error. In that case either:
  - install/renew an Apple Development certificate (Xcode > Settings > Accounts), or
  - re-grant each time with: ./Scripts/bundle.sh --reset-tcc

Override the auto-selection with:
  export VELLSNAP_SIGN_IDENTITY="Some Other Identity"
NOTE
