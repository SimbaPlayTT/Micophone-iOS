# Micophone iOS

A native SwiftUI iOS 16+ client for [Micophone](https://github.com/farzonline/micophone), using its existing Protocol v2 Windows receiver. MIT licensed, no ads, purchases, runtime accounts, telemetry or cloud audio services.

**Validation status:** source and project implemented. **7 Swift core tests, 5 receiver compatibility tests, static project checks and syntax parsing of all Swift sources passed.** The native [GitHub Actions build](https://github.com/SimbaPlayTT/Micophone-iOS/actions/runs/41854735985) is queued without a Mac runner; no iOS compilation, simulator test, archive or IPA has completed yet. See the [test report](Documentation/TestResults.md) for executed evidence. **Physical iPhone recording, Windows audio routing and locked-screen continuity have not been tested.** Background configuration is an implementation, not a verified device guarantee.

## Get the app

**An IPA is not available at delivery while the Mac builds are queued.** The following steps apply after the native workflow succeeds. The complete source and Xcode project are available now.

1. Open **Actions → Build and test iOS → latest successful run**.
2. Download **Micophone-iOS-unsigned**, extract the ZIP, and find `Micophone-iOS-unsigned.ipa`.
3. Sign/install with [Sideloadly](https://sideloadly.io/) or [AltStore Classic](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows), or build directly in Xcode with a free Personal Team. An unsigned IPA cannot be installed directly. Free provisioning expires after seven days and needs renewal.
4. Start the original Windows Micophone receiver, allow its private-network firewall access, and note its IPv4 address.
5. On the same private Wi-Fi, enter that address and port `50005` in the iOS app. Tap **Connect to PC**, allow Local Network, then **Start microphone** and allow Microphone.
6. Route the PC receiver to **CABLE Input** and choose **CABLE Output** as the input in Discord, OBS or your game. See the external-driver caveat below.
7. Lock the phone to perform the documented device test. Tap **Stop microphone** in the app to release capture. Mute keeps capture active but sends silence.

## Build and test

On macOS with Xcode 16+ and an iOS simulator runtime:

```sh
python3 Scripts/check_project.py
python3 -m unittest discover -s Tests/Python -v
swift test
bash Scripts/test_simulator.sh
bash Scripts/build_unsigned.sh
```

Open `Micophone-iOS.xcodeproj` and select the shared **Micophone-iOS** scheme for interactive development. No CocoaPods, third-party Swift packages, XcodeGen or paid Apple capabilities are required. Python 3.10+ reproduces the checked-in project with `Scripts/generate_project.py`. The workflow builds with Apple's SDK on a GitHub macOS runner; Windows alone cannot compile this project.

## Implemented

- AVAudioEngine microphone capture; hardware-rate conversion to 48 kHz or 44.1 kHz, signed 16-bit little-endian mono PCM.
- Exact 10 ms Protocol v2 UDP framing, sequence wrapping, HELLO/ACK/BUSY and 1-second keepalives.
- Manual private IPv4 address and port; unicast connection probe that never starts capture; Wi-Fi-only Network.framework transport.
- Bounded conversion/send queues, latest-audio preference, software gain, silence mute, live peak meter, three buffering presets.
- Explicit start/stop, permission handling, recording status, interruption handling, audio-route/media-service recovery and network reconnection.
- Supported audio background mode with a legitimately active recording session. No silent playback or private APIs.
- Simulator audio-conversion/network tests, portable Swift state/PCM tests, and real UDP tests against pinned upstream receiver code.

## Limits and privacy

Audio is **unencrypted and unauthenticated**, matching upstream. Use only a trusted private LAN. The app restricts entry to RFC1918/link-local IPv4 addresses and requires Wi-Fi; it does not broadcast, scan, accept public IPs or use cellular. Automatic discovery and ADB USB mode are intentionally absent. Bluetooth input uses the call profile when enabled and may have reduced bandwidth. Gain is software amplification; clipping is possible above 1×.

No native or physical test result should be inferred from this README. Incoming calls can stop capture; resumption depends on iOS permission and audio-session availability. Force quitting stops it. Network recovery is attempted while the legitimate recording session remains active; audio background mode does not grant unrestricted background networking.

The iOS app and upstream receiver are MIT open source. The original receiver commonly uses **VB-CABLE**, a separate proprietary, free/donationware virtual audio driver. It is not bundled or relicensed here. Consequently, the complete Discord/OBS routing chain using VB-CABLE is not entirely open source. This port does not supply or claim to have built a free signed open-source Windows virtual microphone driver.

## Documentation

- [Protocol and upstream source evidence](Documentation/Protocol.md)
- [Background behavior and limitations](Documentation/BackgroundAudio.md)
- [Windows compatibility and setup](Documentation/WindowsCompatibility.md)
- [Build, free signing and installation](Documentation/Installation.md)
- [Physical-device test plan](Documentation/DeviceValidation.md)
- [Executed tests and remaining checks](Documentation/TestResults.md)
- [Requirement status](Documentation/RequirementStatus.md)
- [Architecture and threading](Documentation/Architecture.md)

Compatible protocol source: upstream commit `e7d977d3bf5fce6b8666a28f5602c45ab422b1ba` (Micophone 2.0.0). Required upstream notices are retained in [LICENSE](LICENSE), the app's Settings screen and [Upstream](Upstream). See [UPSTREAM.json](Upstream/UPSTREAM.json) for paths and file hashes. No upstream code has been patched.
