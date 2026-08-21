#!/bin/sh

# Xcode Cloud prepares every build from a clean clone. Keep this script next
# to the Xcode workspace so Apple can discover it regardless of the checkout
# directory selected by the workflow.
set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Keep the project metadata aligned with Xcode Cloud's authoritative build
# number. App Store Connect replaces CFBundleVersion with CI_BUILD_NUMBER
# during distribution, so adding an offset here would only create a mismatch.
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  CLOUD_BUILD_NUMBER="$CI_BUILD_NUMBER"
else
  CLOUD_BUILD_NUMBER=30
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

if ! brew list node@22 >/dev/null 2>&1; then
  brew install node@22
fi
export PATH="$(brew --prefix node@22)/bin:$PATH"

echo "Node: $(node --version)"
echo "npm: $(npm --version)"

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
