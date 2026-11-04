#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
device_id=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for k,v in d["devices"].items() if "iOS" in k for x in v if x["isAvailable"] and "iPhone" in x["name"]))')
simulator_arch=$(uname -m)
xcodebuild -project Micophone-iOS.xcodeproj -scheme Micophone-iOS \
  -configuration Debug -destination "platform=iOS Simulator,id=$device_id" \
  -parallel-testing-enabled NO \
  -resultBundlePath "$PWD/build/SimulatorTests.xcresult" \
  ARCHS="$simulator_arch" ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test | tee build/simulator-tests.log
xcrun simctl launch "$device_id" org.micophone.ios
sleep 2
xcrun simctl io "$device_id" screenshot build/SimulatorApp.png
