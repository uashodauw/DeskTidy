import XCTest
@testable import DeskTidyCore

final class ChimeSynthTests: XCTestCase {
    func testLengthMatchesDuration() {
        let expected = Int(ChimeSynth.duration * Double(ChimeSynth.sampleRate))
        XCTAssertEqual(ChimeSynth.samples().count, expected)
    }

    func testIsGentleAndNeverClips() {
        let loudest = ChimeSynth.samples().map(abs).max() ?? 0
        XCTAssertEqual(loudest, ChimeSynth.peakLevel, accuracy: 0.0001)
        XCTAssertLessThan(loudest, 1)
    }

    func testStartsAndEndsSilentlySoThereIsNoClick() {
        let samples = ChimeSynth.samples()
        XCTAssertEqual(samples.first ?? 1, 0, accuracy: 0.0001)
        XCTAssertEqual(samples.last ?? 1, 0, accuracy: 0.0001)
    }

    func testSecondNoteMakesTheMiddleLouderThanTheTail() {
        let samples = ChimeSynth.samples()
        func loudness(_ range: Range<Int>) -> Double {
            samples[range].map(abs).max() ?? 0
        }
        let rate = ChimeSynth.sampleRate
        XCTAssertGreaterThan(loudness(rate * 8 / 100 ..< rate * 15 / 100), loudness(rate * 38 / 100 ..< rate * 42 / 100))
    }

    func testWavHeaderIsValid() {
        let data = ChimeSynth.wavData()
        XCTAssertEqual(String(decoding: data[0..<4], as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8..<12], as: UTF8.self), "WAVE")
        XCTAssertEqual(String(decoding: data[36..<40], as: UTF8.self), "data")
        XCTAssertEqual(data.count, 44 + ChimeSynth.samples().count * 2)
    }
}
