import Foundation

struct StreamState {
    enum Phase: String { case stopped, requestingPermission, capturing, interrupted }
    private(set) var phase: Phase = .stopped
    private(set) var generation = 0
    var wantsCapture: Bool { phase == .capturing || phase == .interrupted }
    mutating func requestStart() -> Int {
        generation += 1
        phase = .requestingPermission
        return generation
    }
    mutating func permit(_ granted: Bool, generation ticket: Int) -> Bool {
        guard generation == ticket, phase == .requestingPermission else { return false }
        phase = granted ? .capturing : .stopped
        return granted
    }
    mutating func stop() { generation += 1; phase = .stopped }
    mutating func interrupt() {
        if phase == .capturing { phase = .interrupted }
    }
    mutating func resume(allowed: Bool) -> Bool {
        guard phase == .interrupted, allowed else { return false }
        phase = .capturing
        return true
    }
}

struct LinkHealth {
    static let timeout: TimeInterval = 2.5
    private(set) var lastReply: TimeInterval?
    private(set) var busy = false
    mutating func reply(busy: Bool, at time: TimeInterval) { lastReply = time; self.busy = busy }
    mutating func reset() { lastReply = nil; busy = false }
    func isFresh(at time: TimeInterval) -> Bool {
        guard let lastReply else { return false }
        return time - lastReply < Self.timeout
    }
    func canSend(at time: TimeInterval) -> Bool { isFresh(at: time) && !busy }
}
