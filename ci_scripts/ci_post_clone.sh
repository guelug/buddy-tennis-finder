#!/bin/sh

set -eu

ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"

echo "Validating Personal Shopper checkout for Xcode Cloud"

test -f PersonalShooper.xcodeproj/project.pbxproj
test -f PersonalShooper.xcodeproj/xcshareddata/xcschemes/PersonalShooper.xcscheme
test -f PersonalShooper/BackendConfig.plist
if git ls-files --error-unmatch PersonalShooper/LocalSecrets.plist >/dev/null 2>&1; then
    echo "LocalSecrets.plist must never be committed" >&2
    exit 1
fi

plutil -lint PersonalShooper/Info.plist
plutil -lint PersonalShooper/BackendConfig.plist
plutil -lint PersonalShooper/PrivacyInfo.xcprivacy

echo "Checkout is ready for build ${CI_BUILD_NUMBER:-local}"
