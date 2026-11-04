import XCTest
import Network
@testable import Micophone_iOS

final class NetworkTests: XCTestCase {
    func testUDPHandshakeAudioMuteStopAndReconnect() throws {
        let server = try NWListener(using: .udp, on: .any)
        let serverQueue = DispatchQueue(label: "test.receiver")
        let serverReady = expectation(description: "UDP listener ready")
        let receivedAudio = expectation(description: "Real UDP PCM packet")
        let receivedSilence = expectation(description: "Muted UDP packet")
        var phase = 0 // Only read and written on serverQueue.
        var peers: [NWConnection] = []
        server.stateUpdateHandler = { if case .ready = $0 { serverReady.fulfill() } }
        server.newConnectionHandler = { peer in
            peers.append(peer)
            func receive() {
                peer.receiveMessage { data, _, _, error in
                    guard error == nil else { return }
                    if let data, data.count >= 3 {
                        if data[2] == 4 {
                            XCTAssertEqual(data, MicophoneProtocol.hello(rate: 48000, name: "Micophone iOS"))
                            peer.send(content: MicophoneProtocol.message(.ack, body: Data("Test PC".utf8)), completion: .idempotent)
                        } else if data[2] == 1 {
                            XCTAssertEqual(data.count, 965)
                            if phase == 0 {
                                XCTAssertEqual(Data(data.dropFirst(5)), Data(repeating: 17, count: 960))
                                phase = 1
                                receivedAudio.fulfill()
                            } else if phase == 1 && data.dropFirst(5).allSatisfy({ $0 == 0 }) {
                                phase = 2
                                receivedSilence.fulfill()
                            }
                        }
                    }
                    receive()
                }
            }
            peer.start(queue: serverQueue)
            receive()
        }
        server.start(queue: serverQueue)
        wait(for: [serverReady], timeout: 10)
        let port = try XCTUnwrap(server.port?.rawValue)
        let client = NetworkStreamingManager(requiresWiFi: false)
        let handshake = expectation(description: "Receiver ACK, not merely UDP ready")
        var didAck = false
        client.onStatus = { if case .streaming = $0, !didAck { didAck = true; handshake.fulfill() } }
        defer {
            client.disconnect()
            server.cancel()
            serverQueue.sync { peers.forEach { $0.cancel() } }
        }
        client.connect(host: "127.0.0.1", port: port)
        client.startStreaming(rate: 48000, bufferPackets: 2)
        // Cold hosted simulators may stall the first Network.framework use.
        // Allow the production timeout/retry cycle; an actual ACK is required.
        wait(for: [handshake], timeout: 20)
        client.enqueue(Data(repeating: 17, count: 960))
        wait(for: [receivedAudio], timeout: 5)
        client.setMuted(true)
        client.enqueue(Data(repeating: 17, count: 960))
        wait(for: [receivedSilence], timeout: 5)
        client.stopStreaming()
        client.enqueue(Data(repeating: 17, count: 960))
        client.disconnect()

        let reconnected = expectation(description: "Explicit reconnect ACK")
        client.onStatus = { if case .streaming = $0 { reconnected.fulfill() } }
        client.connect(host: "127.0.0.1", port: port)
        client.startStreaming(rate: 48000, bufferPackets: 2)
        wait(for: [reconnected], timeout: 10)
    }

    func testUnreachableReceiverReportsFailure() {
        let client = NetworkStreamingManager(requiresWiFi: false)
        let failed = expectation(description: "Unreachable UDP receiver does not appear connected")
        var fulfilled = false
        client.onStatus = { status in
            if case .retrying = status, !fulfilled { fulfilled = true; failed.fulfill() }
            if case .streaming = status { XCTFail("No receiver sent an ACK") }
        }
        client.connect(host: "127.0.0.1", port: 59999)
        client.startStreaming(rate: 48000, bufferPackets: 2)
        wait(for: [failed], timeout: 9)
        client.disconnect()
    }
}
