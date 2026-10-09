import XCTest
@testable import DeskTidyCore

final class CleanSoundTests: XCTestCase {
    private let everything: (String) -> Bool = { _ in true }
    private let nothing: (String) -> Bool = { _ in false }

    func testDefaultIsTheIPhoneMailSound() {
        XCTAssertEqual(CleanSound.defaultValue, .mailSent)
    }

    func testOnlySoundsWithFilesAreListed() {
        let onlyGlass: (String) -> Bool = { $0.hasSuffix("Glass.aiff") }
        XCTAssertEqual(CleanSound.available(fileExists: onlyGlass), [.glass])
    }

    func testFindsMailSoundInEitherLocation() {
        let oldLocation: (String) -> Bool = { $0.hasPrefix("/Applications/Mail.app") }
        XCTAssertEqual(CleanSound.mailSent.path(fileExists: oldLocation), "/Applications/Mail.app/Contents/Resources/Mail Sent.aiff")
    }

    func testMissingChoiceFallsBackToFirstAvailable() {
        let noMail: (String) -> Bool = { !$0.contains("Mail.app") }
        XCTAssertEqual(CleanSound.resolve(.mailSent, fileExists: noMail), .glass)
    }

    func testAvailableChoiceIsKept() {
        XCTAssertEqual(CleanSound.resolve(.tink, fileExists: everything), .tink)
    }

    func testNoSoundsAtAllResolvesToNil() {
        XCTAssertNil(CleanSound.resolve(.mailSent, fileExists: nothing))
    }

    func testEverySoundHasALabelAndAPath() {
        for sound in CleanSound.allCases {
            XCTAssertFalse(sound.label.isEmpty)
            XCTAssertFalse(sound.candidatePaths.isEmpty)
        }
    }
}
