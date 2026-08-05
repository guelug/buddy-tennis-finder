#!/bin/sh
#
# Xcode Cloud post-clone hook for MatchPoint Tennis.
# Compiles on Apple's stable macOS/Xcode (not the local beta host) and
# gives each Cloud archive a unique build number above the local builds.
#
# Local archives on the beta Mac fail ASC processing with
# ITMS-90111: Unsupported SDK or Xcode version. This hook ensures
# the build number is bumped and the deployment target is pinned to
# a stable iOS version.

set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Build numbers from Xcode Cloud start at 100 + CI_BUILD_NUMBER, well
# above any local archive (currently at 24). This avoids collisions.
if [ -n "$CI_BUILD_NUMBER" ]; then
  NEWVER=$((100 + CI_BUILD_NUMBER))
else
  NEWVER=100
fi

python3 - "$NEWVER" <<'PY'
import re
import sys
from pathlib import Path

build_number = sys.argv[1]

# Update app.json buildNumber and versionCode
app_json = Path("app.json")
text = app_json.read_text()
text = re.sub(r'"buildNumber": "\d+"', f'"buildNumber": "{build_number}"', text)
text = re.sub(r'"versionCode": \d+', f'"versionCode": {build_number}', text)
app_json.write_text(text)
print(f"app.json: buildNumber={build_number}, versionCode={build_number}")

# Update Xcode project CURRENT_PROJECT_VERSION
project = Path("ios/MatchPointTennis.xcodeproj/project.pbxproj")
text = project.read_text()
text = re.sub(r"CURRENT_PROJECT_VERSION = \d+;", f"CURRENT_PROJECT_VERSION = {build_number};", text)
# Pin deployment target to stable iOS (avoid beta SDK targets)
text = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = \d+\.\d+;", "IPHONEOS_DEPLOYMENT_TARGET = 18.0;", text)
project.write_text(text)
print(f"project.pbxproj: CURRENT_PROJECT_VERSION={build_number}, IPHONEOS_DEPLOYMENT_TARGET=18.0")
PY

# Install dependencies (Xcode Cloud runs on a clean checkout)
npm ci --include=dev || npm install --include=dev

# Verify
echo "=== Build info ==="
xcodebuild -version
echo "CURRENT_PROJECT_VERSION: $(grep -m1 'CURRENT_PROJECT_VERSION = ' ios/MatchPointTennis.xcodeproj/project.pbxproj | sed 's/[^0-9]//g')"
echo "Build number: $(grep -m1 '"buildNumber"' app.json | sed 's/[^0-9]//g')"
echo "ci_post_clone: MatchPoint Tennis prepared for Xcode Cloud"