# Test results

Date: 2026-11-04. Local implementation host: Windows, Python 3.10. No local Swift toolchain, Xcode, iPhone or Windows virtual audio device was available to this task.

| Check | Actual result |
|---|---|
| Original public repository clone / pinned commit | PASS: inspected `e7d977d3bf5fce6b8666a28f5602c45ab422b1ba` |
| Static project/resource/permission/source-hash validation | PASS: `python Scripts/check_project.py` executed |
| Python actual receiver UDP compatibility | PASS: 5 tests, 0 failures, executed on Windows with loopback access |
| Swift portable PCM/framing/state tests | PASS: compiled with Swift 6.4.2 on GitHub Ubuntu 24.04; 7 tests, 0 failures |
| Native Swift/iOS simulator compilation | PENDING GitHub macOS workflow execution |
| AVAudioConverter and real UDP simulator tests | PENDING GitHub macOS workflow execution |
| Real arm64 device archive / unsigned IPA | PENDING GitHub macOS workflow execution |
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

This confirms compilation/execution of production portable Swift code, not AVFoundation, SwiftUI or Network.framework compilation. Both standard ARM and Intel Mac runner attempts were queued without runner assignment at this point; no native test or IPA success is inferred. Native results and artifacts will be recorded after they complete. The [device test plan](DeviceValidation.md) remains entirely NOT TESTED irrespective of simulator results.
