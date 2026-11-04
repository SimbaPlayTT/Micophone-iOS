# Windows compatibility

## Exact receiver

Protocol compatibility target: [farzonline/micophone commit e7d977d3bf5fce6b8666a28f5602c45ab422b1ba](https://github.com/farzonline/micophone/tree/e7d977d3bf5fce6b8666a28f5602c45ab422b1ba), commit labeled Micophone 2.0.0. The receiver source and protocol parser are included unmodified under `Upstream/`. No Windows change is needed for this port, so Android clients remain compatible. Runtime interoperability with a real iPhone/Windows audio device is NOT TESTED. The byte-level tests exercise this pinned receiver.

Later releases may be compatible if they retain Protocol v2; that is not promised. Use the pinned source when reproducing results, or verify the protocol of your installed release.

## Set up

1. Obtain/build Micophone from the [original repository](https://github.com/farzonline/micophone). To run pinned source:

   ```powershell
   git clone https://github.com/farzonline/micophone.git
   Set-Location micophone
   git checkout e7d977d3bf5fce6b8666a28f5602c45ab422b1ba
   python -m venv .venv
   .\.venv\Scripts\python -m pip install -r pc/requirements.txt
   .\.venv\Scripts\python pc/micophone_gui.py
   ```

2. Install a separate virtual audio driver if you want Windows applications to see a microphone. Upstream recommends [VB-CABLE](https://vb-audio.com/Cable/). Its Windows base driver is offered free/donationware, is proprietary and is not included in this MIT project. Follow its official installation/reboot instructions. This port does not implement a Windows kernel audio driver or claim the full external-driver stack is open source.
3. Choose **CABLE Input** as the receiver's playback output. Choose **CABLE Output** as the input in Discord, OBS, games or Windows Sound settings. Avoid receiver playback through speakers near the phone; it can cause acoustic feedback.
4. Allow Micophone's private-network firewall access. Default Wi-Fi transport is incoming **UDP port 50005**. TCP 50005 is bound to PC loopback for Android USB and is not the iOS Wi-Fi transport.
5. Use the PC's Wi-Fi IPv4 address displayed by Micophone (or `ipconfig`), for example `192.168.1.10`. Connect the iPhone to the same non-guest LAN. Enter that address and `50005` in Micophone iOS. Allow Local Network when prompted, tap Connect, then Start microphone and allow recording.
6. Start with the receiver's **Normal (40 ms)** jitter buffer. Choose Low (20 ms) on a clean LAN or Stable (80 ms) when audio breaks up. Phone capture queue presets do not control this PC setting.

Only one phone can own the receiver at a time. Stop the Android/other iOS client if the PC reports busy. Because the original protocol has no STOP, Windows drops the previous source after 2.5 seconds without HELLO/AUDIO.

## Troubleshooting

| Symptom | Check |
|---|---|
| Connect keeps retrying | Correct private IPv4, same Wi-Fi, Local Network permission, receiver running and private firewall allowance |
| PC ready but no microphone | Tap Start; check Microphone permission and iOS input route |
| Receiver shows audio but Discord does not | Receiver output must be CABLE Input; Discord input must be CABLE Output |
| Busy | Another phone owns the slot; stop it and wait 3 seconds |
| Audio breaks up | Increase PC jitter buffer; select balanced/stable capture preset; verify Wi-Fi quality |
| Phone changed Wi-Fi | Reconnect is attempted at the same address; update the field if PC DHCP address changed |
| No automatic discovery | Expected: iOS uses manual unicast to avoid the restricted broadcast entitlement |
| USB mode unavailable | ADB reverse is Android-specific; no equivalent tunnel is supplied for iOS |

Local UDP traffic has no authentication or encryption. Use a trusted network; do not expose this port to the internet.
