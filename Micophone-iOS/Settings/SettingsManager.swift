import Foundation
import Combine

enum AudioQuality: String, CaseIterable, Identifiable {
    case full = "48 kHz", standard = "44.1 kHz"
    var id: String { rawValue }
    var rate: Int { self == .full ? 48000 : 44100 }
}

enum BufferPreset: String, CaseIterable, Identifiable {
    case low = "Low", balanced = "Balanced", stable = "Stable"
    var id: String { rawValue }
    var duration: Double { self == .low ? 0.01 : self == .balanced ? 0.02 : 0.04 }
    var packets: Int { self == .low ? 2 : self == .balanced ? 4 : 8 }
    var detail: String { "\(Int(duration * 1000)) ms capture preference · \(packets * 10) ms send queue limit" }
}

@MainActor final class SettingsManager: ObservableObject {
    private let defaults: UserDefaults
    @Published var host: String { didSet { defaults.set(host, forKey: "pc.host") } }
    @Published var port: String { didSet { defaults.set(port, forKey: "pc.port") } }
    @Published var quality: AudioQuality { didSet { defaults.set(quality.rawValue, forKey: "audio.quality") } }
    @Published var buffer: BufferPreset { didSet { defaults.set(buffer.rawValue, forKey: "audio.buffer") } }
    @Published var bluetooth: Bool { didSet { defaults.set(bluetooth, forKey: "audio.bluetooth") } }
    @Published var reconnect: Bool { didSet { defaults.set(reconnect, forKey: "network.reconnect") } }
    @Published var gain: Float { didSet { defaults.set(gain, forKey: "audio.gain") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        host = defaults.string(forKey: "pc.host") ?? ""
        port = defaults.string(forKey: "pc.port") ?? "50005"
        quality = AudioQuality(rawValue: defaults.string(forKey: "audio.quality") ?? "") ?? .full
        buffer = BufferPreset(rawValue: defaults.string(forKey: "audio.buffer") ?? "") ?? .balanced
        bluetooth = defaults.bool(forKey: "audio.bluetooth")
        reconnect = defaults.object(forKey: "network.reconnect") as? Bool ?? true
        gain = defaults.object(forKey: "audio.gain") as? Float ?? 1
    }
}
