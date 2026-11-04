# Test results

Date: 2026-11-04. Local implementation host: Windows, Python 3.10. No local Swift toolchain, Xcode, iPhone or Windows virtual audio device was available to this task.

| Check | Actual result |
|---|---|
| Original public repository clone / pinned commit | PASS: inspected `e7d977d3bf5fce6b8666a28f5602c45ab422b1ba` |
| Static project/resource/permission/source-hash validation | PASS: `python Scripts/check_project.py` executed |
| Python actual receiver UDP compatibility | PASS: 5 tests, 0 failures, executed on Windows with loopback access |
| Swift portable PCM/framing/state tests | PENDING GitHub macOS workflow execution |
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

Workflow results, final commit and artifact links will be recorded after native CI completes. The [device test plan](DeviceValidation.md) remains entirely NOT TESTED irrespective of simulator results.
