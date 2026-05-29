#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_PATH="${ROOT_DIR}/build/PersonalShooper.xcarchive"
EXPORT_PATH="${ROOT_DIR}/build/upload"
UPLOAD_OPTIONS="${ROOT_DIR}/build/UploadOptions.plist"

# Load App Store Connect API credentials.
if [[ -f "${ROOT_DIR}/.env.appstoreconnect" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ROOT_DIR}/.env.appstoreconnect"
  set +a
fi

: "${ASC_KEY_ID:?Missing ASC_KEY_ID in .env.appstoreconnect}"
: "${ASC_ISSUER_ID:?Missing ASC_ISSUER_ID in .env.appstoreconnect}"
: "${ASC_KEY_PATH:?Missing ASC_KEY_PATH in .env.appstoreconnect}"

if [[ ! -f "${ASC_KEY_PATH}" ]]; then
  echo "❌  ASC API key file not found: ${ASC_KEY_PATH}" >&2
  exit 1
fi

if [[ ! -d "${ARCHIVE_PATH}" ]]; then
  echo "❌  Archive not found. Run ./scripts/archive.sh first." >&2
  exit 1
fi

cd "${ROOT_DIR}"
mkdir -p build/upload

# Build ExportOptions with destination=upload for direct TestFlight delivery.
cp ExportOptions.plist "${UPLOAD_OPTIONS}"
plutil -replace destination -string upload "${UPLOAD_OPTIONS}"

echo "📤 Exporting and uploading to TestFlight..."
xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${UPLOAD_OPTIONS}" \
  -authenticationKeyPath "${ASC_KEY_PATH}" \
  -authenticationKeyID "${ASC_KEY_ID}" \
  -authenticationKeyIssuerID "${ASC_ISSUER_ID}" \
  -allowProvisioningUpdates

echo ""
echo "✅  Upload complete. Check App Store Connect → Personal Shooper → TestFlight."
