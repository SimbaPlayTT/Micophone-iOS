import AVFoundation
import Foundation

@MainActor final class BackgroundAudioManager {
    enum Event { case interruptionBegan, interruptionEnded(Bool), routeChanged, mediaServicesReset }
    var onEvent: ((Event) -> Void)?
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
            Task { @MainActor [weak self] in
                if type == .began { self?.onEvent?(.interruptionBegan) }
                else { self?.onEvent?(.interruptionEnded(AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume))) }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard raw == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue ||
                    raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue ||
                    raw == AVAudioSession.RouteChangeReason.routeConfigurationChange.rawValue else { return }
            Task { @MainActor [weak self] in self?.onEvent?(.routeChanged) }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.onEvent?(.mediaServicesReset) }
        })
    }

    func activate(rate: Int, duration: Double, bluetooth: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        // No output node is connected and no silent playback is used.
        try session.setCategory(.playAndRecord, mode: bluetooth ? .default : .measurement,
                                options: bluetooth ? [.allowBluetooth] : [])
        try session.setPreferredSampleRate(Double(rate))
        try session.setPreferredIOBufferDuration(duration)
        try session.setActive(true)
        if !bluetooth, let input = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try session.setPreferredInput(input)
        }
    }

    func deactivate() { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    var routeDescription: String {
        let session = AVAudioSession.sharedInstance()
        return session.currentRoute.inputs.map(\.portName).joined(separator: ", ") + " · \(Int(session.sampleRate)) Hz hardware"
    }
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
}
