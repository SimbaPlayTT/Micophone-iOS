# Build, signing and installation

## GitHub Actions from Windows

The repository's `.github/workflows/ios.yml` uses `macos-26` and the runner's selected Xcode. It records toolchain versions, checks the pinned protocol fixtures/project, runs portable Swift tests, builds and tests the app in an available iPhone simulator, then archives an arm64 iPhoneOS app with signing disabled. No Apple certificates, passwords, paid developer account or repository secrets are needed for this unsigned build. GitHub account/Actions access is a development dependency, not an app runtime account requirement.

1. Open [Build and test iOS](https://github.com/SimbaPlayTT/Micophone-iOS/actions/workflows/ios.yml).
2. A push of application/build/test files starts the workflow; **Run workflow** can also start it manually.
3. Select a successful run and download **Micophone-iOS-unsigned** under Artifacts (GitHub may require sign-in to download).
4. Extract the artifact ZIP. It contains the **real compiled, unsigned** `Micophone-iOS-unsigned.ipa`, SHA-256 file and Xcode version. A separate evidence artifact contains test results/logs.

The IPA is a ZIP with `Payload/Micophone-iOS.app` from Xcode's archive. The packaging script refuses a simulator build, missing/non-arm64 Mach-O executable or signed archive. **Unsigned is not installable:** a valid signature/provisioning profile is still required. Do not rename source ZIPs to IPA.

GitHub-hosted runner availability and account quotas are outside the app; public repository standard runners are the intended free build route. No hosted build service subscription is added. Consult [GitHub runner documentation](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job) and [artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts).

## Build in Xcode on a Mac

Requirements: macOS supporting Xcode 16+, Xcode with an iOS 16-or-newer SDK and a simulator runtime, Python 3.10+ for utility scripts. The app has no third-party Swift dependencies.

```sh
git clone https://github.com/SimbaPlayTT/Micophone-iOS.git
cd Micophone-iOS
open Micophone-iOS.xcodeproj
```

Choose the shared **Micophone-iOS** scheme. Build for an iOS simulator to compile without device signing, or select your connected iPhone to sign/run. The checked-in project is complete; regeneration is optional:

```sh
python3 Scripts/generate_project.py
python3 Scripts/check_project.py
python3 -m unittest discover -s Tests/Python -v
swift test
bash Scripts/test_simulator.sh
bash Scripts/build_unsigned.sh
```

The last command produces `build/Micophone-iOS-unsigned.ipa` only after a successful Xcode archive. Simulator tests verify conversion, protocol, state transitions and loopback UDP; they do not verify actual microphone hardware, LAN privacy prompts or background recording.

## Free Personal Team signing in Xcode

1. Add your Apple Account in **Xcode → Settings → Accounts**.
2. Select app target → Signing & Capabilities → Automatically manage signing → your **Personal Team**. Use a unique bundle identifier if Xcode requires it. Select the same team for the test target when running device tests.
3. Connect/trust the iPhone. Enable **Developer Mode** in Settings → Privacy & Security if requested, restart and confirm.
4. Choose the iPhone as destination and Run. If asked, trust the developer under Settings → General → VPN & Device Management.
5. Allow Microphone and Local Network when requested by the app.

Background audio uses `UIBackgroundModes`/AVAudioSession and needs no special signing entitlement. There are deliberately no push, multicast, networking-extension, iCloud or paid-only entitlements. Signing supplies standard application identifiers and team/provisioning values automatically.

Apple documents that a free Personal Team can install up to 3 apps per device, register up to 3 devices/10 App IDs with seven-day expiry, and that provisioning profiles expire after **7 days**. Rebuild/reinstall before expiry or refresh with a compatible sideloading tool. These are Apple's provisioning limits, not an application time limit. A free Apple Account is needed for signing, not to use the app's microphone/network features. See [Apple developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account/) and [signing workflow](https://help.apple.com/xcode/mac/current/en.lproj/dev60b6fbbc7.html).

## Windows/macOS: Sideloadly

1. Download the official [Sideloadly](https://sideloadly.io/) build and follow its current device/Apple software prerequisites.
2. Connect/trust the iPhone. Load the extracted **unsigned IPA**. Use your own free Apple Account and follow the signing prompts in that tool; never put Apple credentials into this repository or workflow.
3. Complete trust/Developer Mode steps requested by iOS, open the app and grant its permissions.
4. Re-sign/refresh within seven days with a free account. Sideloadly provides an optional refresh daemon; follow its official [FAQ](https://sideloadly.io/faq).

Sideloadly is an external signing tool, not a component or dependency of this open-source app. Its Apple authentication may need internet even though microphone streaming is LAN-only.

## Windows/macOS: AltStore Classic

Install AltServer/AltStore **Classic** using its [Windows guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) (or its macOS guide). Follow its current Apple software/trust requirements. Import the built IPA through AltStore's My Apps add control, use your own Apple Account, and refresh the app with AltServer available before free provisioning expires. AltStore itself uses one of the free installed-app slots. This project does not require an AltStore subscription, an external source feed or AltStore PAL distribution.

## Reproduction evidence

Each workflow run is linked to its source commit and records Xcode version and logs. The app source has no remote Swift packages. `Scripts/generate_project.py` uses only Python's standard library. Byte-for-byte archives are not guaranteed across Xcode releases because toolchains and build metadata differ; use the logged runner/Xcode version and commit to reproduce functionality. See [TestResults.md](TestResults.md) for what was actually executed.
