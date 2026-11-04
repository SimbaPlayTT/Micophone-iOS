#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
device_id=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for k,v in d["devices"].items() if "iOS" in k for x in v if x["isAvailable"] and "iPhone" in x["name"]))')
xcodebuild -project Micophone-iOS.xcodeproj -scheme Micophone-iOS \
  -configuration Debug -destination "platform=iOS Simulator,id=$device_id" \
  -resultBundlePath "$PWD/build/SimulatorTests.xcresult" \
  CODE_SIGNING_ALLOWED=NO test | tee build/simulator-tests.log
