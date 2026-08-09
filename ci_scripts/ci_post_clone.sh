#!/bin/sh

# Compatibility entry point for workflows configured from the repository
# root. The authoritative script lives next to the Xcode workspace.
set -eu

exec "$CI_PRIMARY_REPOSITORY_PATH/ios/ci_scripts/ci_post_clone.sh"
