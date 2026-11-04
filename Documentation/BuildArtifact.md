# Compiled unsigned iPhone app

- Successful native build: [41899057773](https://github.com/SimbaPlayTT/Micophone-iOS/actions/runs/41899057773).
- Source commit: `ab54b80fbd781b192068744b75a0c85a4c21ff03`.
- Toolchain: Xcode 16.4, build 16F6, standard macOS 15 Intel runner.
- File: `Micophone-iOS-unsigned.ipa`, 140958 bytes.
- Bundle ID: `org.micophone.ios`; app version 1.0.0; minimum iOS 16.0.
- Executable: real arm64 Mach-O, 359984 bytes, platform `iPhoneOS`.
- SHA-256: `b746bc9eb436c4aa5684e1ae06745a6f293160a305055fee1f5d5264f545ce1f`.
- Signing: **unsigned**; no embedded provisioning profile or code-signature directory. Sign before installation with your own Apple Account.

The downloaded artifact's checksum and Mach-O/platform metadata were independently inspected on Windows. The archive log contains `ARCHIVE SUCCEEDED` and is preserved under `Evidence/DeviceArchive.log`. This is a compiled device app, not a renamed source archive or simulator bundle.

This package-only workflow verifies native compilation and packaging. Simulator test results are reported separately in [TestResults.md](TestResults.md). Physical microphone, Wi-Fi, signed installation and locked-screen operation remain NOT TESTED. Follow the [Windows installation instructions](Installation.md#start-here-if-you-use-windows) to sign/install it.
