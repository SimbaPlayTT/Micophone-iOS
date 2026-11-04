import Foundation

enum PCM16 {
    /// Deterministic saturation and explicit little endian; independent of host byte order.
    static func encode(_ samples: UnsafeBufferPointer<Float>, gain: Float = 1, muted: Bool = false) -> (Data, Float) {
        guard !muted else { return (Data(count: samples.count * 2), 0) }
        var bytes = [UInt8](repeating: 0, count: samples.count * 2)
        var peak: Float = 0
        for (i, sample) in samples.enumerated() {
            let value = sample.isFinite ? max(-1, min(1, sample * gain)) : 0
            peak = max(peak, abs(value))
            let signed = value <= -1 ? Int16.min : Int16((value * 32767).rounded(.towardZero))
            let bits = UInt16(bitPattern: signed)
            bytes[i * 2] = UInt8(truncatingIfNeeded: bits)
            bytes[i * 2 + 1] = UInt8(truncatingIfNeeded: bits >> 8)
        }
        return (Data(bytes), peak)
    }

    static func encode(_ samples: [Float], gain: Float = 1, muted: Bool = false) -> Data {
        samples.withUnsafeBufferPointer { encode($0, gain: gain, muted: muted).0 }
    }
}

struct PCMFramer {
    let bytesPerPacket: Int
    private(set) var pending = Data()

    init(rate: Int) {
        precondition(rate == 48000 || rate == 44100)
        bytesPerPacket = rate / 100 * 2
    }

    mutating func append(_ pcm: Data) -> [Data] {
        precondition(pcm.count.isMultiple(of: 2))
        pending.append(pcm)
        var packets: [Data] = []
        var offset = 0
        while pending.count - offset >= bytesPerPacket {
            packets.append(pending.subdata(in: offset..<(offset + bytesPerPacket)))
            offset += bytesPerPacket
        }
        if offset > 0 { pending = Data(pending.dropFirst(offset)) }
        return packets
    }

    mutating func reset() { pending.removeAll(keepingCapacity: true) }
}

/// Audio producers never create an unbounded dispatch backlog. Drop oldest unsent audio.
final class BoundedPacketQueue {
    private let lock = NSLock()
    private var packets: [Data] = []
    private var limit: Int
    private var drops = 0
    init(capacity: Int) { precondition(capacity > 0); limit = capacity }
    var dropped: Int { lock.lock(); defer { lock.unlock() }; return drops }
    var count: Int { lock.lock(); defer { lock.unlock() }; return packets.count }
    func push(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        if packets.count == limit { packets.removeFirst(); drops += 1 }
        packets.append(data)
    }
    func pop() -> Data? {
        lock.lock(); defer { lock.unlock() }
        return packets.isEmpty ? nil : packets.removeFirst()
    }
    func clear(capacity: Int? = nil, resetDrops: Bool = false) {
        lock.lock(); defer { lock.unlock() }
        packets.removeAll(keepingCapacity: true)
        if let capacity { limit = max(1, capacity) }
        if resetDrops { drops = 0 }
    }
}
