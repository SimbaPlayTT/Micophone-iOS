import XCTest
#if canImport(MicophoneCore)
@testable import MicophoneCore
#else
@testable import Micophone_iOS
#endif

final class CoreTests: XCTestCase {
    func testPCMClippingEndianMuteAndNonFiniteSamples() {
        XCTAssertEqual(PCM16.encode([-2, -1, 0, 1, 2, .nan, .infinity]),
                       Data([0,128, 0,128, 0,0, 255,127, 255,127, 0,0, 0,0]))
        XCTAssertEqual(PCM16.encode([0.5, -0.5], gain: 2), Data([255,127, 0,128]))
        XCTAssertEqual(PCM16.encode([0.9, -0.9], muted: true), Data(count: 4))
    }

    func testFramingAcrossCallbackBoundariesWithoutSampleLoss() {
        for rate in [48000, 44100] {
            var framer = PCMFramer(rate: rate)
            let length = rate / 100 * 2
            let input = Data((0..<(length * 3 + 10)).map { UInt8(truncatingIfNeeded: $0) })
            XCTAssertTrue(framer.append(input.prefix(2)).isEmpty)
            let output = framer.append(Data(input.dropFirst(2)))
            XCTAssertEqual(output.count, 3)
            XCTAssertTrue(output.allSatisfy { $0.count == length })
            XCTAssertEqual(output.reduce(Data(), +) + framer.pending, input)
            framer.reset()
            XCTAssertTrue(framer.pending.isEmpty)
        }
    }

    func testBoundedQueueDropsOldestAndClearsOnStop() {
        let queue = BoundedPacketQueue(capacity: 2)
        for b: UInt8 in [1, 2, 3] { queue.push(Data([b])) }
        XCTAssertEqual(queue.dropped, 1)
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue.pop(), Data([2]))
        XCTAssertEqual(queue.pop(), Data([3]))
        XCTAssertNil(queue.pop())
        queue.push(Data([4]))
        queue.clear(capacity: 1, resetDrops: true)
        XCTAssertEqual(queue.count, 0)
        XCTAssertEqual(queue.dropped, 0)
    }

    func testProtocolFixturesMatchUpstream() throws {
        #if canImport(MicophoneCore)
        let url = try XCTUnwrap(Bundle.module.url(forResource: "protocol-v2", withExtension: "json", subdirectory: "Fixtures"))
        #else
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "protocol-v2", withExtension: "json"))
        #endif
        let f = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(f.upstreamCommit, MicophoneProtocol.upstreamCommit)
        XCTAssertEqual(MicophoneProtocol.hello(rate: f.rate, name: f.phoneName), Data(hex: f.helloHex))
        XCTAssertEqual(MicophoneProtocol.audio(sequence: f.sequence, pcm: Data(hex: f.pcmHex)), Data(hex: f.audioHex))
        XCTAssertEqual(MicophoneProtocol.message(.discover), Data([0x50,0x4d,2]))
        XCTAssertEqual(MicophoneProtocol.control(Data(hex: f.ackHex))?.0, .ack)
        XCTAssertEqual(MicophoneProtocol.control(Data(hex: f.busyHex))?.0, .busy)
        XCTAssertNil(MicophoneProtocol.control(Data([0x50])))
        XCTAssertNil(MicophoneProtocol.control(Data([0x50,0x4d,99])))
        XCTAssertNil(MicophoneProtocol.control(Data([0,0,5])))
        XCTAssertEqual(MicophoneProtocol.hello(rate: 44100, name: String(repeating: "A", count: 100)).count, 71)
        XCTAssertEqual(MicophoneProtocol.audio(sequence: .max, pcm: Data()).suffix(2), Data([255,255]))
    }

    func testConnectionFailureBusyAndRecovery() {
        var health = LinkHealth()
        XCTAssertFalse(health.canSend(at: 0))
        health.reply(busy: true, at: 0)
        XCTAssertTrue(health.isFresh(at: 1))
        XCTAssertFalse(health.canSend(at: 1))
        health.reply(busy: false, at: 1)
        XCTAssertTrue(health.canSend(at: 3.49))
        XCTAssertFalse(health.canSend(at: 3.5))
        health.reset()
        XCTAssertFalse(health.isFresh(at: 4))
        health.reply(busy: false, at: 5)
        XCTAssertTrue(health.canSend(at: 5))
    }

    func testStartStopInterruptionAndPermissionRace() {
        var state = StreamState()
        let first = state.requestStart()
        state.stop()
        XCTAssertFalse(state.permit(true, generation: first))
        let denied = state.requestStart()
        XCTAssertFalse(state.permit(false, generation: denied))
        XCTAssertEqual(state.phase, .stopped)
        let second = state.requestStart()
        XCTAssertTrue(state.permit(true, generation: second))
        state.interrupt()
        XCTAssertEqual(state.phase, .interrupted)
        XCTAssertFalse(state.resume(allowed: false))
        XCTAssertTrue(state.resume(allowed: true))
        state.interrupt()
        state.stop()
        XCTAssertFalse(state.resume(allowed: true))
        XCTAssertFalse(state.wantsCapture)
    }

    func testOnlyPrivateLANEndpointsAreAccepted() {
        for ip in ["192.168.1.10", "10.0.0.1", "172.16.1.2", "169.254.2.3"] { XCTAssertNotNil(EndpointValidation.ipv4(ip)) }
        for ip in ["8.8.8.8", "127.0.0.1", "255.255.255.255", "224.0.0.1", "172.32.0.1", "1.2.3", "192.168.1.999", "PC.local"] { XCTAssertNil(EndpointValidation.ipv4(ip)) }
        XCTAssertNil(EndpointValidation.port("0"))
        XCTAssertNil(EndpointValidation.port("65536"))
        XCTAssertEqual(EndpointValidation.port("50005"), 50005)
    }
}

private struct Fixture: Decodable {
    let upstreamCommit: String, rate: Int, phoneName: String, sequence: UInt16
    let helloHex: String, pcmHex: String, audioHex: String, ackHex: String, busyHex: String
}

private extension Data {
    init(hex: String) {
        let bytes = Array(hex.utf8)
        self.init(stride(from: 0, to: bytes.count, by: 2).map { i in
            UInt8(String(decoding: bytes[i..<(i + 2)], as: UTF8.self), radix: 16)!
        })
    }
}
