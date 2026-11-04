# Background recording: implemented, physical validation pending

**Locked-screen operation has NOT BEEN TESTED on an iPhone.** This document describes supported API configuration and intended behavior, not an observed success claim.

The app declares `UIBackgroundModes = [audio]`. After the user taps Start and grants permission, it configures an input-capable `AVAudioSession` and keeps an AVAudioEngine input tap running. Apple documents continued background recording with an audio background mode and a recording category. This is genuine, visible microphone capture; there is no silent output, private API, background-task timer loop, VoIP entitlement, notification trick, location service or microphone bypass.

References: [Apple recording category](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record), [audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions), [AVAudioConverter sample-rate conversion](https://developer.apple.com/documentation/technotes/tn3136-avaudioconverter-performing-sample-rate-conversions).

The actual app uses `.playAndRecord` with no connected output or playback, so Bluetooth HFP input can optionally be enabled using the public `.allowBluetooth` option. Measurement mode is used with the built-in microphone; Bluetooth uses default mode. Preferred sample rate and I/O duration are requests, not guarantees. Hardware format is queried after activation and converted to the wire format.

| Scenario | Implementation / limitation | Physical observation |
|---|---|---|
| Foreground, screen on | Explicit Start activates permission, session, tap and stream | NOT TESTED |
| Screen locked | Scene changes keep already active capture running; audio background mode configured | NOT TESTED |
| Screen off for 10 minutes | Same active recording path; no artificial timer limit | NOT TESTED |
| Another app foreground | Capture remains requested; competing audio sessions may interrupt | NOT TESTED |
| Incoming call / Siri | Stop tap and outgoing audio on interruption; resume only on shouldResume while still requested | NOT TESTED |
| Bluetooth | Optional HFP input; lower bandwidth may be imposed by hardware/OS; route rebuilds converter | NOT TESTED |
| Wi-Fi disappears | Discard queued audio; retry same PC; keep legitimate active capture visible until user stops | NOT TESTED |
| Wi-Fi returns | Rebuild UDP socket and HELLO; send fresh PCM only after ACK | NOT TESTED |
| Low Power Mode | No special exemption; timing and networking depend on iOS and must be measured | NOT TESTED |
| Force quit / OS termination | App cannot continue recording or restart itself | NOT TESTED |
| Sleep/wake | No restart on scene changes; existing capture should persist if iOS permits; interrupted route recovery supported | NOT TESTED |

Audio background mode does **not** authorize arbitrary background networking. UDP traffic supports the ongoing recording use case. If iOS suspends the process during an interruption, networking/retry timers cannot be assumed to run. iOS may refuse session reactivation in the background; failure is surfaced and the closest supported recovery is to reopen the app and tap Start. No guarantee is made for calls, force quit, thermal/memory termination or unavailable Wi-Fi.

The user must start in the foreground, including initial local-network approval. There is no attempt to secretly activate the microphone after launch, a reboot, a network event or a scene change. While muted the tap remains active, iOS's microphone indicator remains visible and silence is transmitted; Stop releases capture. The in-app status and prominent Stop button stay available on return to the app. No lock-screen control extension is supplied.

Run the [device validation procedure](DeviceValidation.md) before describing a build as supporting locked-screen streaming in production.
