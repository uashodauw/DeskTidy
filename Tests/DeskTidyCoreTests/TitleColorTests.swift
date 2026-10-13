import XCTest
@testable import DeskTidyCore

final class TitleColorTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "DeskTidyTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDesignedColorsAreNearBlackAndWhite() {
        XCTAssertEqual(TitleColor.lightAppearance.hex, "1D1D1F")
        XCTAssertEqual(TitleColor.darkAppearance.hex, "FFFFFF")
    }

    func testHexRoundTripAndHashPrefix() {
        let color = TitleColor(hex: "#3366cc")
        XCTAssertEqual(color?.hex, "3366CC")
        XCTAssertNil(TitleColor(hex: "12345"))
        XCTAssertNil(TitleColor(hex: "GGHHII"))
        XCTAssertNil(TitleColor(hex: "3366CC80"))
    }

    func testFollowSystemUsesTheDesignedPair() {
        let blue = TitleColor(hex: "0000FF")!
        let orange = TitleColor(hex: "FF8800")!
        XCTAssertEqual(
            TitleColor.resolved(mode: .followSystem, isDarkAppearance: false, customLight: blue, customDark: orange),
            .lightAppearance
        )
        XCTAssertEqual(
            TitleColor.resolved(mode: .followSystem, isDarkAppearance: true, customLight: blue, customDark: orange),
            .darkAppearance
        )
    }

    func testCustomUsesTheColorForTheCurrentAppearance() {
        let blue = TitleColor(hex: "0000FF")!
        let orange = TitleColor(hex: "FF8800")!
        XCTAssertEqual(
            TitleColor.resolved(mode: .custom, isDarkAppearance: false, customLight: blue, customDark: orange).hex,
            "0000FF"
        )
        XCTAssertEqual(
            TitleColor.resolved(mode: .custom, isDarkAppearance: true, customLight: blue, customDark: orange).hex,
            "FF8800"
        )
    }

    func testTitleColorsFollowSystemByDefault() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.titleColorMode, .followSystem)
        XCTAssertEqual(settings.titleColorLight, .lightAppearance)
        XCTAssertEqual(settings.titleColorDark, .darkAppearance)
        XCTAssertFalse(settings.recoveredFromCorruptData)
    }

    func testCustomTitleColorsAreRemembered() {
        let settings = AppSettings(defaults: defaults)
        settings.titleColorMode = .custom
        settings.titleColorLight = TitleColor(hex: "112233")!
        settings.titleColorDark = TitleColor(hex: "AABBCC")!
        let reopened = AppSettings(defaults: defaults)
        XCTAssertEqual(reopened.titleColorMode, .custom)
        XCTAssertEqual(reopened.titleColorLight.hex, "112233")
        XCTAssertEqual(reopened.titleColorDark.hex, "AABBCC")
    }

    func testBrokenTitleColorsFallBackToTheDesignedPair() {
        defaults.set("乱码", forKey: AppSettings.titleColorModeKey)
        defaults.set("不是颜色", forKey: AppSettings.titleColorLightKey)
        defaults.set(12, forKey: AppSettings.titleColorDarkKey)
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.titleColorMode, .followSystem)
        XCTAssertEqual(settings.titleColorLight, .lightAppearance)
        XCTAssertEqual(settings.titleColorDark, .darkAppearance)
        XCTAssertTrue(settings.recoveredFromCorruptData)
        XCTAssertNil(defaults.object(forKey: AppSettings.titleColorModeKey))
        XCTAssertNil(defaults.object(forKey: AppSettings.titleColorLightKey))
    }
}