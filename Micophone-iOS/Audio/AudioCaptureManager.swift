import AVFoundation

final class AudioCaptureManager {
    private var engine: AVAudioEngine?
    private let worker = DispatchQueue(label: "micophone.audio.convert", qos: .userInitiated)
    private let admission = NSLock()
    private var generation = 0
    private var pending = 0
    private var accepting = false
    private var muted = false
    private var gain: Float = 1
    private var lastMeter: TimeInterval = 0
    var onPCM: ((Data) -> Void)?
    var onMeter: ((Float) -> Void)?
    var onError: ((Error) -> Void)?

    func setMuted(_ value: Bool) { admission.lock(); muted = value; admission.unlock() }
    func setGain(_ value: Float) { admission.lock(); gain = max(0, min(value, 2)); admission.unlock() }

    /// Called on the main actor, after audio-session activation. No microphone is opened at launch.
    func start(rate: Int, bufferDuration: Double) throws {
        stop()
        let engine = AVAudioEngine()
        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw CaptureError.noInput }
        let converter = try AudioFormatConverter(input: format, rate: rate)
        var framer = PCMFramer(rate: rate)
        admission.lock()
        accepting = true
        let current = generation
        admission.unlock()
        let frames = AVAudioFrameCount(max(128, format.sampleRate * bufferDuration))
        node.installTap(onBus: 0, bufferSize: frames, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.admission.lock()
            guard self.accepting, self.generation == current, self.pending < 3 else {
                self.admission.unlock(); return
            }
            self.pending += 1
            self.admission.unlock()
            // Tap buffers belong to AVAudioEngine. Copy their storage before leaving the callback.
            guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
                self.admission.lock(); self.pending -= 1; self.admission.unlock(); return
            }
            copy.frameLength = buffer.frameLength
            let source = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
            let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
            for i in 0..<source.count {
                if let dst = destination[i].mData, let src = source[i].mData {
                    memcpy(dst, src, Int(source[i].mDataByteSize))
                }
            }
            self.worker.async { [weak self] in
                guard let self else { return }
                defer { self.admission.lock(); self.pending -= 1; self.admission.unlock() }
                self.admission.lock()
                let valid = self.accepting && self.generation == current
                let muted = self.muted, gain = self.gain
                self.admission.unlock()
                guard valid else { return }
                do {
                    let (pcm, peak) = try converter.convert(copy, gain: gain, muted: muted)
                    for packet in framer.append(pcm) { self.onPCM?(packet) }
                    let now = ProcessInfo.processInfo.systemUptime
                    if now - self.lastMeter >= 0.05 { self.lastMeter = now; self.onMeter?(peak) }
                } catch { self.onError?(error) }
            }
        }
        self.engine = engine
        engine.prepare()
        do { try engine.start() } catch { stop(); throw error }
    }

    func stop() {
        admission.lock(); accepting = false; generation += 1; admission.unlock()
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        // Wait for already admitted conversion work before replacing the session or handlers.
        worker.sync {}
    }

    deinit { engine?.stop() }
}
