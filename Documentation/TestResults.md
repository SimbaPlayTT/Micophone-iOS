# Test results

Date: 2026-11-04. Local implementation host: Windows, Python 3.10. No local Swift toolchain, Xcode, iPhone or Windows virtual audio device was available to this task.

| Check | Actual result |
|---|---|
| Original public repository clone / pinned commit | PASS: inspected `e7d977d3bf5fce6b8666a28f5602c45ab422b1ba` |
| Static project/resource/permission/source-hash validation | PASS: `python Scripts/check_project.py` executed |
| Python actual receiver UDP compatibility | PASS: 5 tests, 0 failures, executed on Windows with loopback access |
| Swift portable PCM/framing/state tests | PASS: compiled with Swift 6.4.2 and 6.4.1 on GitHub Ubuntu 24.04; 7 tests, 0 failures per run |
| Syntax parsing of all 18 tracked Swift files | PASS on Swift 6.4.1; parsing only, Apple SDK types not checked |
| Native Swift/iOS simulator compilation | PASS: compiled and linked with Xcode 16.4 |
| AVAudioConverter tests | PASS: both PCM conversion and stereo 44.1-to-48 kHz resampling tests executed |
| Real UDP simulator tests | First run: recovery and unreachable-receiver tests PASS; initial handshake timed out. Rerun 41899415141 in progress |
| Real arm64 device archive / unsigned IPA | PASS: real iPhoneOS archive and unsigned IPA produced in run 41899057773 |
| Signed installation / physical mic audio / Windows routing | NOT TESTED |
| Screen locked, 10-minute continuity, interruptions and Bluetooth | NOT TESTED |

Python execution:

```text
test_44100_format_and_malformed_messages ... ok
test_actual_receiver_buffer_priming_and_overrun ... ok
test_busy_and_restart_from_new_socket ... ok
test_fixture_matches_actual_receiver_and_accepts_PCM ... ok
test_sequence_wrap_loss_duplicate_and_late_packets ... ok
Ran 5 tests in 0.583s — OK
```

An initial restricted-environment loopback run timed out. The identical tests passed with local network access enabled; no protocol code was changed to make that result pass. For macOS portability, the BUSY test subsequently models an existing source on a synthetic different address before sending real UDP HELLO, rather than binding an unconfigured loopback alias. The Python suite imports the unmodified receiver with only its sounddevice module stubbed, so physical PortAudio/VB-CABLE playback is not covered. The original receiver's full `test_receiver.py` was inspected and retained, but was not run against physical Windows sound hardware.

## Executed Swift CI

[Successful portable Swift/receiver run 41854102679](https://github.com/SimbaPlayTT/Micophone-iOS/actions/runs/41854102679), commit `2bc39823e3ad6955df9863f921d5afa67f07e705`. Application and test source is identical to main revision `daa7e5f`; the branch adds only the portable workflow. Swift 6.4.2, x86_64 Linux. The checked-in evidence log is `Evidence/SwiftCoreTests.log`.

```text
CoreTests.testBoundedQueueDropsOldestAndClearsOnStop ... passed
CoreTests.testConnectionFailureBusyAndRecovery ... passed
CoreTests.testFramingAcrossCallbackBoundariesWithoutSampleLoss ... passed
CoreTests.testOnlyPrivateLANEndpointsAreAccepted ... passed
CoreTests.testPCMClippingEndianMuteAndNonFiniteSamples ... passed
CoreTests.testProtocolFixturesMatchUpstream ... passed
CoreTests.testStartStopInterruptionAndPermissionRace ... passed
Executed 7 tests, with 0 failures (0 unexpected)
```

Main-branch runs [41854736134](https://github.com/SimbaPlayTT/Micophone-iOS/actions/runs/41854736134) and [41855747914](https://github.com/SimbaPlayTT/Micophone-iOS/actions/runs/41855747914) also succeeded. The latter uses commit `04e452cf255400c487fb4017c876de87a4ffa32e`, Swift 6.4.1 and additionally parses every tracked Swift file with the real compiler's `-frontend -parse` mode. Its logs are `Evidence/SwiftCoreTests-main.log` and `Evidence/SwiftSyntax.log`.

This confirms compilation/execution of production portable Swift code and whole-source syntax validity, not AVFoundation, SwiftUI or Network.framework type checking/linking.

## Native build and simulator execution

The earlier ARM/Intel requests failed before compilation because GitHub could not allocate a hosted runner. A later Intel retry received a runner and compiled the app successfully. Xcode 16.4 (16F6) is recorded in `Evidence/XcodeVersion.txt`.

- [First simulator execution, run 41897439702](https://github.com/SimbaPlayTT/Micophone-iOS/actions/runs/41897439702), source `6d69ce7`: **11 of 12 tests passed**. Both AVAudioConverter tests, seven core tests, actual connection failure and automatic recovery tests passed. The first handshake test exceeded its five-second allowance while the first Network.framework callbacks were delayed on the cold simulator. This run is recorded as FAILED, not PASSED.
- The harness now explicitly boots/reuses the simulator and allows up to 20 seconds for an actual ACK, including the production timeout/retry cycle. PCM packet and mute assertions are unchanged. Production network timeouts and app source are unchanged. [Rerun 41899415141](https://github.com/SimbaPlayTT/Micophone-iOS/actions/runs/41899415141) is in progress.
- [Device archive, run 41899057773](https://github.com/SimbaPlayTT/Micophone-iOS/actions/runs/41899057773), source `ab54b80`: **PASS**, real arm64 iPhoneOS app archived and packaged. See [BuildArtifact.md](BuildArtifact.md) for checksum and independent ZIP/Mach-O inspection. The complete archive log is retained as `Evidence/DeviceArchive.log`.

Native compilation and packaging are verified. The complete simulator suite is not marked passed until its rerun succeeds. The [device test plan](DeviceValidation.md) remains entirely NOT TESTED irrespective of simulator results.
