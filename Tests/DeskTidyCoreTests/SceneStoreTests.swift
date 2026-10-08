import XCTest
@testable import DeskTidyCore

final class SceneStoreTests: XCTestCase {
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

    func testHasThreeDefaultScenesWithUniqueIDs() {
        let scenes = DefaultScenes.all
        XCTAssertEqual(scenes.map(\.name), ["AI 工作", "做设计", "开会"])
        XCTAssertEqual(Set(scenes.map(\.id)).count, scenes.count)
    }

    func testDefaultScenesUseBundleIDs() {
        let aiWork = DefaultScenes.all[0]
        XCTAssertTrue(aiWork.keptBundleIDs.contains("com.apple.Safari"))
        XCTAssertFalse(aiWork.keptBundleIDs.contains("Safari"))
    }

    func testFirstSceneIsSelectedByDefault() {
        XCTAssertEqual(SceneStore(defaults: defaults).selectedScene.name, "AI 工作")
    }

    func testSelectionIsRememberedByANewStore() {
        SceneStore(defaults: defaults).select(sceneID: "meeting")
        XCTAssertEqual(SceneStore(defaults: defaults).selectedScene.name, "开会")
    }

    func testUnknownSceneIDIsIgnored() {
        let store = SceneStore(defaults: defaults)
        store.select(sceneID: "design")
        store.select(sceneID: "does-not-exist")
        XCTAssertEqual(store.selectedScene.id, "design")
    }

    func testFallsBackToFirstSceneWhenSavedIDIsStale() {
        defaults.set("removed-scene", forKey: SceneStore.selectedSceneKey)
        XCTAssertEqual(SceneStore(defaults: defaults).selectedScene.id, "ai-work")
    }
}
