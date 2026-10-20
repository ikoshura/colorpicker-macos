#!/bin/bash
#
# Builds the native macOS Colorpicker app.
# Requires Xcode (with xcodegen installed: brew install xcodegen).
#
set -euo pipefail
cd "$(dirname "$0")"

xcodegen generate

xcodebuild \
  -project Colorpicker.xcodeproj \
  -scheme Colorpicker \
  -configuration Release \
  -derivedDataPath build \
  -quiet \
  build CODE_SIGN_IDENTITY=-

APP="build/Build/Products/Release/Colorpicker.app"
echo "Built: $(pwd)/$APP"
echo "Run with: open $APP"
