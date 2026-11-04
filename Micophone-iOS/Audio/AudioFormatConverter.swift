import AVFoundation

final class AudioFormatConverter {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private let inputRate: Double

    init(input: AVAudioFormat, rate: Int) throws {
        guard let output = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(rate),
                                         channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: input, to: output) else {
            throw CaptureError.unsupportedFormat
        }
        self.converter = converter
        self.outputFormat = output
        self.inputRate = input.sampleRate
        converter.primeMethod = .none
        // Explicit, predictable multichannel downmix before encoding mono PCM.
        converter.downmix = true
    }

    func convert(_ input: AVAudioPCMBuffer, gain: Float, muted: Bool) throws -> (Data, Float) {
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * outputFormat.sampleRate / inputRate)) + 256
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw CaptureError.unsupportedFormat
        }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, state in
            guard !supplied else { state.pointee = .noDataNow; return nil }
            supplied = true
            state.pointee = .haveData
            return input
        }
        if status == .error { throw error ?? (CaptureError.conversionFailed as NSError) }
        guard let channel = output.floatChannelData?[0] else { throw CaptureError.unsupportedFormat }
        return PCM16.encode(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)), gain: gain, muted: muted)
    }
}

enum CaptureError: LocalizedError {
    case noInput, unsupportedFormat, conversionFailed
    var errorDescription: String? {
        switch self {
        case .noInput: return "No microphone input is available. Check your audio route."
        case .unsupportedFormat: return "This microphone format could not be converted to mono PCM."
        case .conversionFailed: return "Audio conversion failed. Stop and restart the microphone."
        }
    }
}
