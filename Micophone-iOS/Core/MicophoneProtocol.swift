import Foundation

enum MicophoneProtocol {
    static let defaultPort: UInt16 = 50005
    static let upstreamCommit = "e7d977d3bf5fce6b8666a28f5602c45ab422b1ba"
    enum Kind: UInt8 { case audio = 1, discover, announce, hello, ack, busy }

    static func message(_ kind: Kind, body: Data = Data()) -> Data {
        Data([0x50, 0x4d, kind.rawValue]) + body
    }

    static func hello(rate: Int, name: String) -> Data {
        let r = UInt32(rate)
        return message(.hello, body: Data([
            UInt8(truncatingIfNeeded: r), UInt8(truncatingIfNeeded: r >> 8),
            UInt8(truncatingIfNeeded: r >> 16), UInt8(truncatingIfNeeded: r >> 24)
        ]) + Data(name.utf8.prefix(64)))
    }

    static func audio(sequence: UInt16, pcm: Data) -> Data {
        message(.audio, body: Data([UInt8(truncatingIfNeeded: sequence),
                                    UInt8(truncatingIfNeeded: sequence >> 8)]) + pcm)
    }

    static func control(_ data: Data) -> (Kind, String)? {
        let bytes = Array(data)
        guard bytes.count >= 3, bytes[0] == 0x50, bytes[1] == 0x4d,
              let kind = Kind(rawValue: bytes[2]),
              [.announce, .ack, .busy].contains(kind) else { return nil }
        return (kind, String(decoding: bytes.dropFirst(3).prefix(64), as: UTF8.self))
    }
}

enum EndpointValidation {
    /// The receiver listens on IPv4. Restrict manual entry to private/link-local LAN addresses.
    static func ipv4(_ text: String) -> String? {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var octets: [UInt8] = []
        for p in parts {
            guard !p.isEmpty, p.allSatisfy({ $0.isASCII && $0.isNumber }), let n = UInt8(p) else { return nil }
            octets.append(n)
        }
        let a = octets[0], b = octets[1]
        guard a == 10 || (a == 172 && (16...31).contains(b)) ||
                (a == 192 && b == 168) || (a == 169 && b == 254) else { return nil }
        return octets.map(String.init).joined(separator: ".")
    }

    static func port(_ text: String) -> UInt16? {
        guard let n = UInt16(text), n > 0 else { return nil }
        return n
    }
}
