#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodebuild >/dev/null || { echo "Requires macOS with Xcode selected by xcode-select." >&2; exit 1; }
mkdir -p build
xcodebuild -version | tee build/xcode-version.txt
xcodebuild -project Micophone-iOS.xcodeproj -scheme Micophone-iOS \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$PWD/build/Micophone-iOS.xcarchive" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  archive | tee build/archive.log
python3 Scripts/package_ipa.py build/Micophone-iOS.xcarchive build/Micophone-iOS-unsigned.ipa
