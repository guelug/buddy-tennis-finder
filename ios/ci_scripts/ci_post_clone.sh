#!/bin/sh

# Xcode Cloud prepares every build from a clean clone. Keep this script next
# to the Xcode workspace so Apple can discover it regardless of the checkout
# directory selected by the workflow.
set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Use a Cloud-only build number so TestFlight never collides with a local
# archive. CI_BUILD_NUMBER is monotonically increasing for the Cloud product.
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  CLOUD_BUILD_NUMBER=$((100 + CI_BUILD_NUMBER))
else
  CLOUD_BUILD_NUMBER=100
fi

python3 - "$CLOUD_BUILD_NUMBER" <<'PY'
import re
import sys
from pathlib import Path

build_number = sys.argv[1]

app_json = Path("app.json")
contents = app_json.read_text()
contents = re.sub(r'"buildNumber": "\d+"', f'"buildNumber": "{build_number}"', contents)
contents = re.sub(r'"versionCode": \d+', f'"versionCode": {build_number}', contents)
app_json.write_text(contents)

project = Path("ios/MatchPointTennis.xcodeproj/project.pbxproj")
contents = project.read_text()
contents = re.sub(
    r"CURRENT_PROJECT_VERSION = \d+;",
    f"CURRENT_PROJECT_VERSION = {build_number};",
    contents,
)
project.write_text(contents)

print(f"Xcode Cloud build number: {build_number}")
PY

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  brew install node
fi

npm ci --include=dev
npx expo install --check
npm run typecheck
npm run i18n:validate
npm test

if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi

cd ios
pod install

echo "Xcode Cloud dependencies and production checks completed"
