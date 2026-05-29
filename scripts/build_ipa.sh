#!/usr/bin/env bash
# Build iprox.app via Theos, package as TrollStore-installable .ipa.
set -uo pipefail

THEOS="${THEOS:-$HOME/theos}"
export THEOS
export PATH="$THEOS/bin:$HOME/.local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

echo "==== compiling ===="
make clean >/dev/null 2>&1 || true
make 2>&1 | tail -40

# Locate built .app bundle
APP_DIR=""
for cand in \
  ".theos/obj/debug/iprox.app" \
  ".theos/obj/iprox.app" \
  ".theos/_/Applications/iprox.app" \
  ".theos/_/var/jb/Applications/iprox.app"; do
  [[ -d "$cand" ]] && APP_DIR="$cand" && break
done

if [[ -z "$APP_DIR" ]]; then
  echo "no .app produced — searching:"
  find .theos -name 'iprox.app' -type d 2>/dev/null
  exit 71
fi
echo "==== app bundle: $APP_DIR ===="

# Ensure Info.plist + binary present
ls -la "$APP_DIR"

# Stage Payload tree on ext4
STAGE=/tmp/iprox-ipa
rm -rf "$STAGE"
mkdir -p "$STAGE/Payload"
cp -a "$APP_DIR" "$STAGE/Payload/iprox.app"

# Make sure our Info.plist is the one in the bundle (Theos usually copies it)
if [[ ! -f "$STAGE/Payload/iprox.app/Info.plist" ]]; then
  cp App/Info.plist "$STAGE/Payload/iprox.app/Info.plist"
fi

# PkgInfo
printf 'APPL????' > "$STAGE/Payload/iprox.app/PkgInfo"

# Sign binary with entitlements (TrollStore honors embedded entitlements)
BIN="$STAGE/Payload/iprox.app/iprox"
chmod 0755 "$BIN"
ldid -SApp/entitlements.plist "$BIN"

# Perms
find "$STAGE/Payload/iprox.app" -type d -exec chmod 0755 {} +
find "$STAGE/Payload/iprox.app" -type f -exec chmod 0644 {} +
chmod 0755 "$BIN"

# Zip into .ipa
mkdir -p packages
IPA="packages/iProx_0.2.0.ipa"
rm -f "$IPA"
( cd "$STAGE" && zip -qr9 "$OLDPWD/$IPA" Payload )

echo "==== artifact ===="
ls -la "$IPA"
echo "==== ipa contents ===="
unzip -l "$IPA" | head -40
echo "==== binary archs + entitlements ===="
lipo -info "$BIN" 2>/dev/null || file "$BIN"
ldid -e "$BIN" 2>/dev/null | head -20
