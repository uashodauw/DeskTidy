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

    private let calculator = "com.apple.calculator"

    private func keptIDs(_ store: SceneStore, _ sceneID: String) -> [String] {
        store.scenes.first { $0.id == sceneID }?.keptBundleIDs ?? []
    }

    func testAddingAnAppToAScene() {
        let store = SceneStore(defaults: defaults)
        store.setApp(calculator, kept: true, inSceneID: "ai-work")
        XCTAssertTrue(keptIDs(store, "ai-work").contains(calculator))
        XCTAssertFalse(keptIDs(store, "design").contains(calculator))
    }

    func testAddingTheSameAppTwiceKeepsOneEntry() {
        let store = SceneStore(defaults: defaults)
        store.setApp(calculator, kept: true, inSceneID: "ai-work")
        store.setApp(calculator, kept: true, inSceneID: "ai-work")
        XCTAssertEqual(keptIDs(store, "ai-work").filter { $0 == calculator }.count, 1)
    }

    func testRemovingAnAppFromAScene() {
        let store = SceneStore(defaults: defaults)
        store.setApp("com.apple.Safari", kept: false, inSceneID: "ai-work")
        XCTAssertFalse(keptIDs(store, "ai-work").contains("com.apple.Safari"))
    }

    func testEditedSceneIsRememberedByANewStore() {
        SceneStore(defaults: defaults).setApp(calculator, kept: true, inSceneID: "ai-work")
        XCTAssertTrue(keptIDs(SceneStore(defaults: defaults), "ai-work").contains(calculator))
    }

    func testUnknownSceneIsIgnoredWhenEditing() {
        let store = SceneStore(defaults: defaults)
        store.setApp(calculator, kept: true, inSceneID: "does-not-exist")
        XCTAssertEqual(store.scenes, DefaultScenes.all)
    }

    func testUnreadableSavedScenesFallBackToDefaults() {
        defaults.set(Data("not json".utf8), forKey: SceneStore.scenesKey)
        XCTAssertEqual(SceneStore(defaults: defaults).scenes, DefaultScenes.all)
    }
}
