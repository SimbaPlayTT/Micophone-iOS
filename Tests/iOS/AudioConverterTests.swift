import XCTest
import AVFoundation
@testable import Micophone_iOS

final class AudioConverterTests: XCTestCase {
    func testRealAVFoundationConversionToPCM16() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
        let input = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480))
        input.frameLength = 480
        for i in 0..<480 { input.floatChannelData![0][i] = 0.5 }
        let converter = try AudioFormatConverter(input: format, rate: 48000)
        let (pcm, peak) = try converter.convert(input, gain: 1, muted: false)
        XCTAssertEqual(pcm, Data(repeatingPattern: [255, 63], count: 480))
        XCTAssertEqual(peak, 0.5, accuracy: 0.001)
        let muted = try converter.convert(input, gain: 2, muted: true)
        XCTAssertEqual(muted.0, Data(count: 960))
        XCTAssertEqual(muted.1, 0)
    }

    func testStatefulResampling44100To48000AndStereoDownmix() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2))
        let input = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 441))
        input.frameLength = 441
        for ch in 0..<2 { for i in 0..<441 { input.floatChannelData![ch][i] = 0.25 } }
        let converter = try AudioFormatConverter(input: format, rate: 48000)
        var pcm = Data()
        for _ in 0..<100 { pcm += try converter.convert(input, gain: 1, muted: false).0 }
        // Allow the converter's finite resampling filter delay; reject duplication or large loss.
        XCTAssertEqual(Double(pcm.count / 2), 48000, accuracy: 256)
        XCTAssertFalse(pcm.allSatisfy { $0 == 0 })
    }
}

private extension Data {
    init(repeatingPattern: [UInt8], count: Int) { self.init(Array(repeating: repeatingPattern, count: count).flatMap { $0 }) }
}
