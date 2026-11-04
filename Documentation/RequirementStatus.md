# Implementation and validation status

| Requirement | Implementation | Verification / remaining work |
|---|---|---|
| Native iOS 16+ app / Xcode project | SwiftUI, AVFoundation, AVAudioSession, AVAudioEngine, Network.framework; no third-party Swift dependencies | PASS: native simulator compilation and arm64 iPhoneOS archive with Xcode 16.4 |
| Free, open-source, ad-free, no purchases/time limits | MIT app/receiver source; no analytics, accounts or cloud at runtime | Source inspection; Apple's seven-day free signing expiry still applies |
| Real microphone and mono conversion | Hardware input tap; stateful AVAudioConverter to 48/44.1 kHz mono Float32, saturation to little-endian PCM16 | PCM encoder/framing and both actual AVAudioConverter tests PASS; hardware NOT TESTED |
| Original Windows compatibility | Exact Protocol v2 HELLO/ACK/BUSY, 10 ms UDP PCM, wrapping sequence | Real pinned receiver parser and UDP fixture tests PASS; physical playback and app-to-PC run NOT TESTED |
| Connect/disconnect, Start/Stop, mute and meter | Implemented native controls; Connect alone never opens mic | Core state/permission-race tests PASS; full UI/device behavior NOT TESTED |
| Gain, quality, buffering and preferences | Software gain 0–2×, 48/44.1 kHz, three queue/capture presets, Bluetooth option, retry preference | PCM/queue tests PASS; live hardware controls NOT TESTED; no unsupported hardware gain claim |
| Locked screen and other foreground app | Legitimate active recording session plus audio background mode; scene changes preserve requested capture | Config checked; physical locked-screen continuity NOT TESTED; no guarantee made |
| Calls, route changes, service reset | Interruption suspension; shouldResume gate; debounced engine/converter rebuild | Portable interruption state tests PASS; Apple notifications/recovery on hardware NOT TESTED |
| Network failures / recovery | ACK freshness, bounded queues, 1 s retry, no stale audio bursts, Wi-Fi-only transport | PASS: complete native simulator network suite, including handshake, PCM delivery, mute, stop/reconnect, failure and automatic recovery; physical Wi-Fi NOT TESTED |
| Discovery / pairing | Manual private IPv4 + port, unicast probe | UDP probe tested against actual parser; automatic broadcast deliberately omitted to avoid restricted entitlement; no secure pairing exists upstream |
| Security/privacy | Standard permissions, explicit Start, visible Stop, no audio files, cellular prohibited | Source/config inspection; protocol is unencrypted/unauthenticated |
| Free signing / sideloading | Xcode Personal Team, AltStore Classic and Sideloadly instructions | Installation NOT TESTED; unsigned IPA is not directly installable |
| Build artifacts | Reproducible Xcode archive and real-Mach-O IPA packaging scripts; Actions workflow | PASS: real unsigned iPhoneOS IPA produced and checksum/platform independently verified |
| Physical device validation | Complete reproducible procedure and observation sheet | All cases NOT TESTED; device/iOS/version/log fields explicitly unrecorded |
| Entire Windows audio chain open source | App and receiver MIT; external driver not supplied | VB-CABLE is proprietary free/donationware. A fully open-source signed virtual-mic driver is not part of this port |

The native build and all 12 simulator tests passed. Physical validation remains pending. See [TestResults.md](TestResults.md), [BuildArtifact.md](BuildArtifact.md), [DeviceValidation.md](DeviceValidation.md) and [Installation.md](Installation.md).
