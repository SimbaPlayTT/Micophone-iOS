import Foundation
import Combine
import UIKit
import OSLog

@MainActor final class ConnectionManager: ObservableObject {
    @Published private(set) var state = StreamState()
    @Published private(set) var connection: NetworkStreamingManager.Status = .disconnected
    @Published private(set) var statusText = "Ready when you are"
    @Published private(set) var message = "Enter the IPv4 address shown by Micophone on your PC."
    @Published private(set) var muted = false
    @Published private(set) var level: Float = 0
    @Published private(set) var route = "Microphone is off"
    @Published private(set) var sent = 0
    @Published private(set) var dropped = 0
    let settings: SettingsManager
    let permissions: PermissionManager
    private let audio = AudioCaptureManager()
    private let network = NetworkStreamingManager()
    private let background = BackgroundAudioManager()
    private let logger = Logger(subsystem: "org.micophone.ios", category: "Streaming")
    private var restartTask: Task<Void, Never>?
    private var linkGeneration = 0
    private var foreground = true

    var isRecording: Bool { state.phase == .capturing }
    var hasSession: Bool { state.phase != .stopped }
    var isConnected: Bool {
        if case .ready = connection { return true }
        if case .streaming = connection { return true }
        return false
    }
    var hasLink: Bool { connection != .disconnected }

    init(settings: SettingsManager, permissions: PermissionManager) {
        self.settings = settings
        self.permissions = permissions
        background.onEvent = { [weak self] in self?.handle($0) }
    }

    private func endpoint() -> (String, UInt16)? {
        guard let host = EndpointValidation.ipv4(settings.host), let port = EndpointValidation.port(settings.port) else {
            message = "Enter a local PC IPv4 address (for example 192.168.1.10) and a port from 1 to 65535."
            return nil
        }
        return (host, port)
    }

    func connect() {
        guard let (host, port) = endpoint() else { return }
        linkGeneration += 1
        let ticket = linkGeneration
        network.onStatus = { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self, self.linkGeneration == ticket else { return }
                if case .streaming(let name) = status, !self.state.wantsCapture {
                    // A callback queued before Stop must not restore a streaming label afterward.
                    self.connection = .ready(name)
                    self.updateStatus(.ready(name))
                } else {
                    self.connection = status
                    self.updateStatus(status)
                }
            }
        }
        network.onStatistics = { [weak self] sent, dropped in
            Task { @MainActor [weak self] in
                guard let self, self.linkGeneration == ticket else { return }
                self.sent = sent; self.dropped = dropped
            }
        }
        connection = .connecting
        network.connect(host: host, port: port)
    }

    func disconnect() {
        stop()
        linkGeneration += 1
        network.disconnect()
        connection = .disconnected
        statusText = "Disconnected"
    }

    func start() async {
        guard state.phase == .stopped, foreground, endpoint() != nil else { return }
        let ticket = state.requestStart()
        statusText = "Microphone permission"
        let granted = await permissions.requestMicrophone()
        guard state.permit(granted, generation: ticket) else {
            if state.generation == ticket { statusText = "Microphone access needed"; message = "Allow Microphone in iOS Settings, then try again." }
            return
        }
        guard foreground else { stop(); message = "Return to the app and tap Start microphone."; return }
        if !hasLink { connect() }
        do {
            muted = false
            audio.setMuted(false)
            network.setMuted(false)
            try startCapture()
            statusText = "Microphone active"
            message = "Connecting to your PC. Recording remains active during Wi-Fi recovery until you tap Stop."
            logger.info("User started microphone; background audio configured")
        } catch { fail(error) }
    }

    private func startCapture() throws {
        let ticket = state.generation
        try background.activate(rate: settings.quality.rate, duration: settings.buffer.duration, bluetooth: settings.bluetooth)
        audio.setGain(settings.gain)
        audio.onPCM = { [weak network = self.network] in network?.enqueue($0) }
        audio.onMeter = { [weak self] level in
            Task { @MainActor [weak self] in
                guard let self, self.state.generation == ticket, self.isRecording else { return }
                self.level = self.muted ? 0 : level
            }
        }
        audio.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self, self.state.generation == ticket else { return }
                self.fail(error)
            }
        }
        network.startStreaming(rate: settings.quality.rate, bufferPackets: settings.buffer.packets)
        try audio.start(rate: settings.quality.rate, bufferDuration: settings.buffer.duration)
        route = background.routeDescription
    }

    func stop() {
        state.stop()
        restartTask?.cancel(); restartTask = nil
        audio.stop()
        network.stopStreaming()
        background.deactivate()
        muted = false; level = 0; route = "Microphone is off"
        statusText = hasLink ? "Microphone stopped" : "Disconnected"
        message = "Microphone is off. The receiver releases the previous source within 2.5 seconds."
        logger.info("Microphone stopped and audio session deactivated")
    }

    func toggleMute() {
        muted.toggle()
        audio.setMuted(muted)
        network.setMuted(muted)
        level = 0
    }

    func updateGain() { audio.setGain(settings.gain) }

    func sceneChanged(active: Bool) {
        foreground = active
        permissions.refresh()
        // Scene changes never start the microphone. An active recording continues normally.
        if !active && !state.wantsCapture && hasLink { disconnect() }
    }

    private func updateStatus(_ status: NetworkStreamingManager.Status) {
        switch status {
        case .disconnected: statusText = "Disconnected"
        case .connecting: statusText = isRecording ? "Microphone active · connecting" : "Finding PC"
        case .ready(let name):
            statusText = state.phase == .interrupted ? "Microphone interrupted" : "PC ready · \(name)"
            if !hasSession { message = "Connected to \(name). Tap Start microphone to send audio." }
        case .streaming(let name):
            statusText = state.phase == .interrupted ? "Microphone interrupted" : "Streaming to \(name)"
            message = "\(settings.quality.rawValue) · 16-bit mono PCM · local Wi-Fi · unencrypted"
        case .busy(let name):
            statusText = "\(name) is using another phone"
            message = "Stop the other phone or tap Stop here. Your audio is not sent while the PC reports busy."
        case .retrying(let reason):
            statusText = "Reconnecting"
            message = reason
            logger.notice("Network recovery: \(reason, privacy: .public)")
            if !settings.reconnect { disconnect(); message = reason }
        }
    }

    private func handle(_ event: BackgroundAudioManager.Event) {
        switch event {
        case .interruptionBegan:
            guard state.wantsCapture else { return }
            state.interrupt()
            restartTask?.cancel()
            audio.stop()
            network.stopStreaming()
            level = 0
            statusText = "Microphone interrupted"
            message = "iOS is using the microphone for a call or another audio session."
            logger.notice("Audio interruption began")
        case .interruptionEnded(let allowed):
            guard state.phase == .interrupted else { return }
            if state.resume(allowed: allowed) { scheduleRestart() }
            else { stop(); message = "iOS did not permit automatic resumption. Tap Start after the call ends." }
        case .routeChanged, .mediaServicesReset:
            guard isRecording else { return }
            audio.stop()
            network.stopStreaming()
            scheduleRestart()
        }
    }

    private func scheduleRestart() {
        restartTask?.cancel()
        let ticket = state.generation
        restartTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
            guard let self, !Task.isCancelled, self.state.generation == ticket, self.isRecording else { return }
            do { try self.startCapture(); self.statusText = "Microphone resumed"; self.logger.info("Audio capture rebuilt") }
            catch { self.fail(error) }
        }
    }

    private func fail(_ error: Error) {
        stop()
        statusText = "Microphone stopped"
        message = error.localizedDescription
        logger.error("Audio stopped: \(error.localizedDescription, privacy: .public)")
    }
}
