import Foundation
import Network

final class NetworkStreamingManager {
    enum Status: Equatable {
        case disconnected, connecting, ready(String), streaming(String), busy(String), retrying(String)
    }
    var onStatus: ((Status) -> Void)?
    var onStatistics: ((Int, Int) -> Void)?
    private let queue = DispatchQueue(label: "micophone.network", qos: .userInitiated)
    private let packets = BoundedPacketQueue(capacity: 4)
    private let ingressLock = NSLock()
    private var accepting = false
    private var wakeScheduled = false
    private var connection: NWConnection?
    private var timer: DispatchSourceTimer?
    private var endpoint: (String, UInt16)?
    private var health = LinkHealth()
    private var streaming = false
    private var transportReady = false
    private var inFlight = false
    private var muted = false
    private var rate = 48000
    private var sequence: UInt16 = 0
    private var openedAt: TimeInterval = 0
    private var retryAt: TimeInterval = 0
    private var lastHello: TimeInterval = 0
    private var sent = 0
    private var token = UUID()
    private var lastStatus: Status = .disconnected
    private let requiresWiFi: Bool

    init(requiresWiFi: Bool = true) { self.requiresWiFi = requiresWiFi }
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func connect(host: String, port: UInt16) {
        queue.sync {
            disconnectInternal()
            endpoint = (host, port)
            sent = 0
            packets.clear(resetDrops: true)
            publish(.connecting)
            open()
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + .milliseconds(250), repeating: .milliseconds(250))
            timer.setEventHandler { [weak self] in self?.tick() }
            self.timer = timer
            timer.resume()
        }
    }

    func disconnect() { queue.sync { disconnectInternal(); publish(.disconnected) } }

    func startStreaming(rate: Int, bufferPackets: Int) {
        queue.sync {
            self.rate = rate
            streaming = true
            health.reset()
            ingressLock.lock()
            packets.clear(capacity: bufferPackets)
            accepting = true
            ingressLock.unlock()
            sendHello()
        }
    }

    func stopStreaming() {
        queue.sync {
            streaming = false
            ingressLock.lock(); accepting = false; packets.clear(); ingressLock.unlock()
            health.reset()
            // A new socket allows a new HELLO to start a fresh receiver source immediately.
            closeTransport()
            if endpoint != nil { open() }
        }
    }

    func setMuted(_ value: Bool) {
        queue.sync { muted = value; packets.clear() }
    }

    func enqueue(_ pcm: Data) {
        ingressLock.lock()
        guard accepting else { ingressLock.unlock(); return }
        packets.push(pcm)
        let needsWake = !wakeScheduled
        wakeScheduled = true
        ingressLock.unlock()
        if needsWake { queue.async { [weak self] in self?.drain() } }
    }

    private func open() {
        guard let (host, port) = endpoint, let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let parameters = NWParameters.udp
        if requiresWiFi { parameters.requiredInterfaceType = .wifi }
        parameters.prohibitedInterfaceTypes = [.cellular]
        parameters.allowLocalEndpointReuse = false
        let c = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: parameters)
        connection = c
        token = UUID()
        let current = token
        openedAt = now
        health.reset()
        c.stateUpdateHandler = { [weak self, weak c] state in
            guard let self, let c, self.token == current else { return }
            switch state {
            case .ready:
                self.transportReady = true
                self.receive(c, token: current)
                self.sendHello()
            case .waiting(let error), .failed(let error):
                self.retry(error.localizedDescription)
            default: break
            }
        }
        c.start(queue: queue)
    }

    private func closeTransport() {
        token = UUID()
        transportReady = false
        inFlight = false
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        health.reset()
        packets.clear()
        releaseWake()
    }

    private func disconnectInternal() {
        ingressLock.lock(); accepting = false; ingressLock.unlock()
        streaming = false
        endpoint = nil
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
        closeTransport()
    }

    private func tick() {
        guard endpoint != nil else { return }
        if connection == nil {
            if now >= retryAt { open() }
        } else {
            if let reply = health.lastReply, now - reply >= LinkHealth.timeout {
                retry("PC stopped responding. Check Wi-Fi, permissions and receiver.")
            } else if health.lastReply == nil && now - openedAt > 5 {
                retry("No PC reply. Allow Local Network access and UDP in Windows Firewall.")
            } else if now - lastHello >= 1 { sendHello() }
        }
        onStatistics?(sent, packets.dropped)
    }

    private func sendHello() {
        guard transportReady, let connection else { return }
        lastHello = now
        // Probe with DISCOVER over unicast; connecting alone never activates the microphone.
        let data = streaming ? MicophoneProtocol.hello(rate: rate, name: "Micophone iOS") : MicophoneProtocol.message(.discover)
        let current = token
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self, self.token == current else { return }
            if let error { self.retry(error.localizedDescription) }
        })
    }

    private func receive(_ c: NWConnection, token current: UUID) {
        c.receiveMessage { [weak self, weak c] data, _, _, error in
            guard let self, let c, self.token == current else { return }
            if let error { self.retry(error.localizedDescription); return }
            if let data, let (kind, name) = MicophoneProtocol.control(data) {
                if self.streaming && (kind == .ack || kind == .busy) {
                    self.health.reply(busy: kind == .busy, at: self.now)
                    self.publish(kind == .ack ? .streaming(name) : .busy(name))
                    self.drain()
                } else if !self.streaming && kind == .announce {
                    self.health.reply(busy: false, at: self.now)
                    self.publish(.ready(name))
                }
            }
            self.receive(c, token: current)
        }
    }

    private func releaseWake() {
        ingressLock.lock(); wakeScheduled = false; ingressLock.unlock()
    }

    private func drain() {
        guard !inFlight else { return }
        guard streaming, transportReady, health.canSend(at: now), let connection else {
            packets.clear(); releaseWake(); return
        }
        // Clear the wake flag and check the queue under the producer's lock to avoid a lost wake.
        ingressLock.lock()
        guard let pcm = packets.pop() else {
            wakeScheduled = false; ingressLock.unlock(); return
        }
        wakeScheduled = true
        ingressLock.unlock()
        guard pcm.count == rate / 100 * 2 else { drain(); return }
        let data = MicophoneProtocol.audio(sequence: sequence, pcm: muted ? Data(count: pcm.count) : pcm)
        sequence &+= 1
        inFlight = true
        let current = token
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self, self.token == current else { return }
            self.inFlight = false
            if let error { self.retry(error.localizedDescription); return }
            self.sent += 1
            self.drain()
        })
    }

    private func retry(_ reason: String) {
        closeTransport()
        retryAt = now + 1
        publish(.retrying(reason))
    }

    private func publish(_ status: Status) {
        guard lastStatus != status else { return }
        lastStatus = status
        onStatus?(status)
    }

    deinit { timer?.cancel(); connection?.cancel() }
}
