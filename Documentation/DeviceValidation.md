# Physical-device validation record

**All cases below are NOT TESTED. No physical iPhone or Windows audio-routing session was available during source implementation.** Fill this record with observed evidence; do not turn intended behavior into a PASS.

## Record before starting

- App commit / IPA SHA-256: NOT RECORDED
- iPhone model / iOS version: NOT AVAILABLE
- Windows version / PC model: NOT AVAILABLE
- Micophone receiver commit: target `e7d977d3bf5fce6b8666a28f5602c45ab422b1ba`; installed version NOT RECORDED
- Virtual audio driver/version: NOT AVAILABLE
- Wi-Fi AP/band, private-network firewall state: NOT RECORDED
- Selected rate / capture preset / PC jitter target: NOT RECORDED
- Bluetooth route, Low Power Mode and battery level: NOT RECORDED
- Start/end local timestamps and time zone: NOT RECORDED

Use a trusted private Wi-Fi network. Start the receiver, select CABLE Input, and select CABLE Output in a recording/call app on Windows. Monitor receiver counters and record the received signal on the PC for this test. Do not record other people without their agreement. Record exact times of actions and corresponding audio gaps; a meter alone does not establish continuous reception.

| Case | Procedure and expected behavior | Observed / logs | Result |
|---|---|---|---|
| Unlocked | Connect and Start. Read a timed phrase; Windows receives intelligible live audio | None | NOT TESTED |
| Locked | Press the side button during speech; continue reading | None | NOT TESTED |
| 10 minutes screen off | Keep an audible timed source near the mic, lock for ≥10 minutes, inspect PC recording for gaps; log packet/loss counters | None | NOT TESTED |
| Other foreground app | Switch to a non-audio app for 2 minutes; verify continuity | None | NOT TESTED |
| Muted | Tap Mute, speak for 10 seconds; receiver should receive zero PCM after in-flight/buffered pre-mute audio drains. Unmute should restore fresh audio | None | NOT TESTED |
| Wi-Fi interruption | Disable AP connectivity for 15 seconds; confirm visible retry on return and recovery after same Wi-Fi returns, without stale queued audio | None | NOT TESTED |
| Explicit Stop | Stop during speech; iOS mic indicator should go away, audio packets stop, receiver releases source within 2.5 s. Re-lock/wake must not restart capture | None | NOT TESTED |
| Incoming call | Call the iPhone; confirm mic/stream pause. End/decline the call; note shouldResume/restart or visible manual-restart requirement | None | NOT TESTED |
| PC receiver closes | Quit receiver during capture; app should show retry without crashing. Reopen and observe fresh HELLO/ACK/audio | None | NOT TESTED |
| Bluetooth | Enable option before connecting, attach HFP headset, record actual route/rate and perceived quality; remove it during recording | None | NOT TESTED |
| Low Power Mode | Repeat 10-minute locked test with Low Power Mode on; compare timestamps/gaps | None | NOT TESTED |
| Force quit | Swipe app away during streaming; recording must end and must not restart itself | None | NOT TESTED |
| Sleep/wake cycles | Lock/unlock 10 times while active, then repeat after Stop; stopped state must remain stopped | None | NOT TESTED |
| Permissions denied | Deny mic/local-network separately; verify actionable explanation, no unintended recording, and recovery after Settings approval | None | NOT TESTED |
| Receiver busy | Start Android client first; iOS must show BUSY and withhold PCM; stop Android and observe recovery | None | NOT TESTED |

Collect the receiver log from `%LOCALAPPDATA%\Micophone\micophone.log`, the PC audio recording, and iOS Console/Xcode logs filtered by subsystem `org.micophone.ios`, category `Streaming`. Logs contain state/errors, not audio. For a signing/sideload-only installation, connect the phone to macOS Console when available; otherwise preserve PC logs plus screen recordings and timestamps. Keep unredacted LAN identifiers/logs private when sharing issues.

PASS requires the observed audio result and an explicit device/version/commit record. Mark unsupported/refused background resumption as a limitation with the actual iOS error. Native compilation or passing simulator tests cannot close these cases.
