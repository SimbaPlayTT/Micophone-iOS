import XCTest
import Network
@testable import Micophone_iOS

final class RecoveryTests: XCTestCase {
    func testAutomaticRecoveryAfterReceiverStartsAnswering() throws {
        let queue = DispatchQueue(label: "test.recovering.receiver")
        let listener = try NWListener(using: .udp, on: .any)
        let ready = expectation(description: "Listener ready")
        let timedOut = expectation(description: "No ACK produces retry")
        let recovered = expectation(description: "Automatic retry receives ACK")
        var answer = false // Protected by the listener's queue.
        var peers: [NWConnection] = []
        listener.stateUpdateHandler = { if case .ready = $0 { ready.fulfill() } }
        listener.newConnectionHandler = { peer in
            peers.append(peer)
            func receive() {
                peer.receiveMessage { data, _, _, error in
                    guard error == nil else { return }
                    if answer, let data, data.count >= 3, data[2] == 4 {
                        peer.send(content: MicophoneProtocol.message(.ack, body: Data("Recovered PC".utf8)), completion: .idempotent)
                    }
                    receive()
                }
            }
            peer.start(queue: queue)
            receive()
        }
        listener.start(queue: queue)
        wait(for: [ready], timeout: 3)
        let client = NetworkStreamingManager(requiresWiFi: false)
        var reportedFailure = false, reportedRecovery = false
        client.onStatus = { status in
            if case .retrying = status, !reportedFailure {
                reportedFailure = true
                queue.async { answer = true }
                timedOut.fulfill()
            }
            if case .streaming = status, !reportedRecovery {
                reportedRecovery = true
                recovered.fulfill()
            }
        }
        defer {
            client.disconnect()
            listener.cancel()
            queue.sync { peers.forEach { $0.cancel() } }
        }
        client.connect(host: "127.0.0.1", port: try XCTUnwrap(listener.port?.rawValue))
        client.startStreaming(rate: 48000, bufferPackets: 2)
        wait(for: [timedOut, recovered], timeout: 12, enforceOrder: true)
    }
}
