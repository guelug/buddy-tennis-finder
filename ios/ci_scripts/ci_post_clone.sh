#!/bin/sh
set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH"
npm ci

cd ios
pod install
