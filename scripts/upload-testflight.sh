#!/usr/bin/env bash
# MatchPoint Tennis → TestFlight
#
# Flujo probado (build 22 y 23):
#   1. Bump build en app.json + ios/.../project.pbxproj
#   2. Archive Release genérico iOS
#   3. Export IPA local (ExportOptions-Local)
#   4. xcrun altool --upload-app con API key ASC
#
# Por qué NO se usa el Mac local como "fuente de verdad" estable:
#   este host corre macOS beta. Apple y los pods a veces se pelean con
#   SDKs beta. Xcode Cloud (macOS estable de Apple) es el camino preferido
#   cuando el producto CI exista en App Store Connect.
#
# Estado Xcode Cloud (2026-08):
#   - ci_scripts/ci_post_clone.sh ya hace `npm ci` + `pod install`
#   - En ASC, MatchPoint Tennis AÚN NO tiene ciProduct (solo LunaCycle y LoLEsports)
#   - Hasta crear el workflow en Xcode → Product → Xcode Cloud, este script
#     es el upload local de respaldo (mismo método que build 22/23).
#
# Credenciales:
#   ~/.appstoreconnect/private_keys/AuthKey_Q2FTX4KKUY.p8
#   ASC_KEY_ID=Q2FTX4KKUY
#   ASC_ISSUER_ID=1d27a2f2-265a-4650-a4a7-84929712d622
#
# Uso:
#   ./scripts/upload-testflight.sh              # usa archive ya existente más reciente 1.2.3-N
#   ./scripts/upload-testflight.sh --archive    # archiva + exporta + sube
#   BUILD=24 ./scripts/upload-testflight.sh --archive
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ASC_KEY_ID="${ASC_KEY_ID:-Q2FTX4KKUY}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-1d27a2f2-265a-4650-a4a7-84929712d622}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"
TEAM_ID="${TEAM_ID:-Y6VZTXTFW8}"
MARKETING_VERSION="${MARKETING_VERSION:-1.2.3}"

if [[ ! -f "$ASC_KEY_PATH" ]]; then
  echo "Missing ASC key: $ASC_KEY_PATH" >&2
  exit 1
fi

# Read current build from pbxproj if BUILD not provided
if [[ -z "${BUILD:-}" ]]; then
  BUILD="$(grep -m1 'CURRENT_PROJECT_VERSION = ' ios/MatchPointTennis.xcodeproj/project.pbxproj | sed 's/[^0-9]//g')"
fi
ARCHIVE="ios/build/MatchPointTennis-${MARKETING_VERSION}-${BUILD}.xcarchive"
IPA_DIR="ios/build/ipa-${BUILD}"
LOCAL_PLIST="ios/ExportOptions-Local.plist"

write_local_plist() {
  cat > "$LOCAL_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>uploadSymbols</key>
  <true/>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
</dict>
</plist>
PLIST
}

do_archive() {
  mkdir -p ios/build
  rm -rf "$ARCHIVE" "$IPA_DIR"
  echo "==> Archiving ${MARKETING_VERSION} (${BUILD})…"
  xcodebuild \
    -workspace ios/MatchPointTennis.xcworkspace \
    -scheme MatchPointTennis \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" \
    archive \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic
}

do_export() {
  write_local_plist
  echo "==> Exporting IPA…"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$IPA_DIR" \
    -exportOptionsPlist "$LOCAL_PLIST" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
}

do_upload() {
  local ipa="$IPA_DIR/MatchPointTennis.ipa"
  if [[ ! -f "$ipa" ]]; then
    echo "IPA not found: $ipa" >&2
    exit 1
  fi
  echo "==> Verifying CFBundleVersion inside IPA…"
  local ver
  ver="$(unzip -p "$ipa" 'Payload/MatchPointTennis.app/Info.plist' | plutil -extract CFBundleVersion raw -)"
  echo "    CFBundleVersion=$ver (expected $BUILD)"
  if [[ "$ver" != "$BUILD" ]]; then
    echo "Refusing upload: IPA build $ver != expected $BUILD" >&2
    exit 1
  fi
  echo "==> Uploading to App Store Connect…"
  xcrun altool --upload-app \
    -f "$ipa" \
    -t ios \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"
  echo "==> UPLOAD DONE. Processing in ASC usually takes 10–30 min."
}

case "${1:-}" in
  --archive)
    do_archive
    do_export
    do_upload
    ;;
  --export-only)
    do_export
    do_upload
    ;;
  ""|--upload)
    if [[ ! -d "$ARCHIVE" ]]; then
      echo "Archive missing ($ARCHIVE). Run with --archive." >&2
      exit 1
    fi
    if [[ ! -f "$IPA_DIR/MatchPointTennis.ipa" ]]; then
      do_export
    fi
    do_upload
    ;;
  *)
    echo "Usage: $0 [--archive|--export-only|--upload]" >&2
    exit 2
    ;;
esac
