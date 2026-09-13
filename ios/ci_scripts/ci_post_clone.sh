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
  CLOUD_BUILD_NUMBER=29
fi

python3 - "$CLOUD_BUILD_NUMBER" <<'PY'
import json
import re
import sys
from pathlib import Path

build_number = sys.argv[1]

app_json = Path("app.json")
config = json.loads(app_json.read_text())
marketing = str(config.get("expo", {}).get("version") or "1.2.6")
config.setdefault("expo", {}).setdefault("ios", {})["buildNumber"] = str(build_number)
config.setdefault("expo", {}).setdefault("android", {})["versionCode"] = int(build_number)
app_json.write_text(json.dumps(config, indent=2) + "\n")

project = Path("ios/MatchPointTennis.xcodeproj/project.pbxproj")
contents = project.read_text()
contents = re.sub(
    r"CURRENT_PROJECT_VERSION = \d+;",
    f"CURRENT_PROJECT_VERSION = {build_number};",
    contents,
)
contents = re.sub(
    r"MARKETING_VERSION = [^;]+;",
    f"MARKETING_VERSION = {marketing};",
    contents,
)
project.write_text(contents)

info = Path("ios/MatchPointTennis/Info.plist")
if info.exists():
    import plistlib
    data = plistlib.loads(info.read_bytes())
    data["CFBundleShortVersionString"] = marketing
    data["CFBundleVersion"] = str(build_number)
    info.write_bytes(plistlib.dumps(data))

print(f"Xcode Cloud build number: {build_number}; marketing: {marketing}")
PY

if ! brew list node@22 >/dev/null 2>&1; then
  brew install node@22
fi
export PATH="$(brew --prefix node@22)/bin:$PATH"

echo "Node: $(node --version)"
echo "npm: $(npm --version)"

npm ci --include=dev
# Expo's compatibility catalog changes independently of this locked build.
# Keep the check visible in Cloud logs, but do not fail the clone on newly
# published patch recommendations (same approach as Arena).
if ! npx expo install --check; then
  echo "warning: Expo recommends dependency updates; continuing with package-lock.json"
fi
npm run typecheck
npm run i18n:validate
npm test

if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi

cd ios
pod install

echo "Xcode Cloud dependencies and production checks completed"
