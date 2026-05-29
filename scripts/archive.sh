#!/usr/bin/env bash
# Build a fresh App Store-ready archive + IPA for Personal Shooper.
#
# Usage:
#   ./scripts/archive.sh

set -euo pipefail

cd "$(dirname "$0")/.."

echo "🧹 Cleaning previous build..."
rm -rf build/PersonalShooper.xcarchive build/ipa

echo "🔁 Regenerating Xcode project..."
xcodegen generate

echo "📦 Archiving..."
xcodebuild -project PersonalShooper.xcodeproj \
  -scheme PersonalShooper \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/PersonalShooper.xcarchive \
  -allowProvisioningUpdates \
  archive

echo ""
echo "📤 Exporting IPA..."
xcodebuild -exportArchive \
  -archivePath build/PersonalShooper.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates

echo ""
echo "✅ Done."
echo "   IPA: $(pwd)/build/ipa/PersonalShooper.ipa"
echo "   Size: $(du -h build/ipa/PersonalShooper.ipa | cut -f1)"
echo ""
echo "Next: ./scripts/upload-testflight.sh"
