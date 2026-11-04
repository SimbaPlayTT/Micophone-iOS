# Protocol compatibility report

## Inspected source

Cloned `https://github.com/farzonline/micophone`, pinned at `e7d977d3bf5fce6b8666a28f5602c45ab422b1ba`, commit subject “Micophone 2.0.0: use an Android phone as a Windows PC microphone”. The repository has Kotlin/Gradle Android code in `android/`, Python Windows GUI/engine code in `pc/`, release documentation in `docs/`, and GitHub release/signing configuration. License: MIT, copyright 2026 Farzonline.

Primary evidence, rather than inferred wire behavior:

- [`Protocol.kt`](https://github.com/farzonline/micophone/blob/e7d977d3bf5fce6b8666a28f5602c45ab422b1ba/android/app/src/main/java/com/farzonline/micophone/Protocol.kt): constants, serialization, discovery and Wi-Fi binding.
- [`StreamService.kt`](https://github.com/farzonline/micophone/blob/e7d977d3bf5fce6b8666a28f5602c45ab422b1ba/android/app/src/main/java/com/farzonline/micophone/StreamService.kt): `openRecorder`, `stream`, `WifiLink`, `UsbLink`.
- [`receiver.py`](https://github.com/farzonline/micophone/blob/e7d977d3bf5fce6b8666a28f5602c45ab422b1ba/pc/receiver.py): protocol docstring, `_udp_loop`, `_claim`, `_on_audio`, `_usb_client`, `JitterBuffer`, `_open_stream`.

Unmodified copies are included under `Upstream/` with SHA-256 hashes in `UPSTREAM.json`. The iOS app implements the UDP path; no changes to Android or Windows are necessary for byte compatibility.

## Capture and playback

Android uses `AudioRecord`, trying 48000 Hz and then 44100 Hz, `CHANNEL_IN_MONO` and `ENCODING_PCM_16BIT`. Its source is `VOICE_COMMUNICATION` when voice processing is selected, otherwise `MIC`; it optionally attaches Android's `NoiseSuppressor`. Reads are `sampleRate / 100 * 2` bytes (10 ms). Mute fills samples with zero. Audio is raw PCM: no codec, compression, WAV header, timestamp or length prefix on UDP.

Windows binds IPv4 UDP on `0.0.0.0:50005` and TCP on `127.0.0.1:50005`. The output is `sounddevice.RawOutputStream` with `channels=1`, `dtype=int16`, and the rate announced by the phone. WASAPI output is preferred and uses its auto-convert option. It prefers a device named `CABLE Input`; without a virtual capture driver the receiver is an output player, not itself a Windows capture device.

## UDP datagrams

Every message starts with bytes `50 4d` (ASCII `PM`), then one type byte. Integers are little endian.

| Type | Value | Body | Direction |
|---|---:|---|---|
| AUDIO | 1 | uint16 sequence + PCM | phone → PC |
| DISCOVER | 2 | empty | phone → PC/broadcast |
| ANNOUNCE | 3 | UTF-8 PC name | PC → phone |
| HELLO | 4 | uint32 rate + UTF-8 phone name, max 64 name bytes | phone → PC |
| ACK | 5 | UTF-8 PC name | PC → phone |
| BUSY | 6 | UTF-8 PC name | PC → phone |

At 48 kHz, AUDIO is 5 header bytes + 960 PCM bytes = **965 bytes**. At 44.1 kHz it is **887 bytes**. Sequence increments modulo 65536. HELLO has no name-length byte on UDP. Example HELLO for `Micophone iOS` at 48 kHz:

```text
50 4d 04 80 bb 00 00 4d 69 63 6f 70 68 6f 6e 65 20 69 4f 53
```

HELLO is repeated once a second. The receiver accepts rates 8000 through 96000 inclusive, though the Android and iOS clients select 48000/44100. HELLO claims the current source and returns ACK or BUSY. Only one source is active. A different UDP socket from the same IPv4 address replaces the source immediately; another address must wait for the old source to become stale. Source staleness is 2.5 seconds; HELLO and accepted AUDIO refresh `last_seen`. There is no STOP message. Stopping capture without further HELLO/AUDIO frees the slot through timeout.

Android's ACK freshness deadline is 2500 ms. Its socket is rebuilt after >4 seconds without replies and it may broadcast rediscovery by remembered PC name. iOS uses a 2.5-second reply deadline after a reply, a 5-second initial timeout, and a 1-second retry delay. It only transmits AUDIO after a fresh ACK. UDP socket `.ready` alone never means a PC is connected.

## Discovery and USB

Android broadcasts DISCOVER repeatedly, to subnet broadcasts and `255.255.255.255`, collecting ANNOUNCE replies. There is no pairing code, cryptographic identity or authentication. iOS uses unicast DISCOVER to the manually entered address to check PC readiness without claiming a live source. Broadcast discovery is not used because iOS requires the multicast entitlement for raw broadcast; manual unicast needs no such entitlement.

TCP is only the Android USB tunnel: phone sends `PM + 04 + rate:uint32LE + nameLength:uint8 + name`, then an unframed PCM byte stream. PC responds once a second with `type:uint8 + nameLength:uint8 + name` (no `PM`). TCP chunk boundaries are arbitrary; receiver carries an odd byte into the next chunk. `_adb_loop` invokes `adb reverse tcp:PORT tcp:PORT`. There is no ADB on normal iOS; this mode was not ported or exposed as a Wi-Fi TCP mode.

## Buffering, loss and security

Receiver rejects AUDIO bodies of <=2 bytes or odd byte length, and ignores packets from a socket other than the current source. Sequence gaps are `(new - old) & 0xffff`: gap 0 and gaps >0x8000 are discarded as duplicate/late. Missing 1–2 packets repeat the last PCM packet; larger gaps are counted without repetition. This is loss concealment, not retransmission or ordered delivery.

`JitterBuffer` targets 20/40/80 ms, primes before playback, and pads underruns with zero. Beyond 3× target it drops old audio back to target. Drift correction drops/repeats at most one sample per 50 ms based on smoothed fill. These settings remain PC controls; the phone cannot change the receiver jitter target via Protocol v2.

There is no encryption, authentication, integrity tag or secure pairing in either transport. PC names are informational. A malicious LAN peer can spoof/control/intercept audio; restricting local addresses and interfaces does not make UDP secure. TLS would require a new protocol and modified receiver and was not silently added.

## Evidence tests

`Tests/Core/Fixtures/protocol-v2.json` contains actual byte fixtures. Swift tests compare the production packet builder to these fixtures. Python tests send the fixtures to the pinned receiver's real `_udp_loop` over loopback UDP and check signed samples, 44.1/48 kHz, discovery, ACK/BUSY, sequence wrap, loss concealment, duplicate/late rejection, invalid packets and buffering. A sounddevice import stub isolates physical playback only; it does not replace the protocol parser. End-to-end physical audio is a separate, unperformed test.
