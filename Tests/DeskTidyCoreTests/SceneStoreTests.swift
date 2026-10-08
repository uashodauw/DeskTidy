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
        XCTAssertEqual(SceneStore(defaults: defaults).selectedScene?.name, "AI 工作")
    }

    func testSelectionIsRememberedByANewStore() {
        SceneStore(defaults: defaults).select(sceneID: "meeting")
        XCTAssertEqual(SceneStore(defaults: defaults).selectedScene?.name, "开会")
    }

    func testUnknownSceneIDIsIgnored() {
        let store = SceneStore(defaults: defaults)
        store.select(sceneID: "design")
        store.select(sceneID: "does-not-exist")
        XCTAssertEqual(store.selectedScene?.id, "design")
    }

    func testFallsBackToFirstSceneWhenSavedIDIsStale() {
        defaults.set("removed-scene", forKey: SceneStore.selectedSceneKey)
        XCTAssertEqual(SceneStore(defaults: defaults).selectedScene?.id, "ai-work")
    }

    func testChoosingNoSceneClearsSelection() {
        let store = SceneStore(defaults: defaults)
        store.selectNoScene()
        XCTAssertNil(store.selectedScene)
        XCTAssertEqual(store.keptBundleIDs, [])
    }

    func testNoSceneIsRememberedByANewStore() {
        SceneStore(defaults: defaults).selectNoScene()
        XCTAssertNil(SceneStore(defaults: defaults).selectedScene)
    }

    func testChoosingASceneAfterNoSceneSelectsIt() {
        let store = SceneStore(defaults: defaults)
        store.selectNoScene()
        store.select(sceneID: "meeting")
        XCTAssertEqual(store.selectedScene?.id, "meeting")
        XCTAssertEqual(store.keptBundleIDs, DefaultScenes.all[2].keptBundleIDs)
    }

    func testNoSceneLeavesSceneContentsUntouched() {
        let store = SceneStore(defaults: defaults)
        store.selectNoScene()
        XCTAssertEqual(SceneStore(defaults: defaults).scenes, DefaultScenes.all)
    }

    func testNoSceneKeepsOnlyTheCurrentAppWhenCleaning() {
        let store = SceneStore(defaults: defaults)
        store.selectNoScene()
        let safari = RunningApp(bundleID: "com.apple.Safari", name: "Safari", processID: 1)
        let notes = RunningApp(bundleID: "com.apple.Notes", name: "备忘录", processID: 2)
        let hidden = CleanupPlanner.appsToHide(running: [safari, notes], current: notes, keptBundleIDs: store.keptBundleIDs)
        XCTAssertEqual(hidden, [safari])
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
        let store = SceneStore(defaults: defaults)
        XCTAssertEqual(store.scenes, DefaultScenes.all)
        XCTAssertTrue(store.recoveredFromCorruptData)
    }

    func testFreshInstallIsNotReportedAsRecovered() {
        XCTAssertFalse(SceneStore(defaults: defaults).recoveredFromCorruptData)
    }

    func testTextInsteadOfScenesIsRecovered() {
        defaults.set("乱码乱码", forKey: SceneStore.scenesKey)
        let store = SceneStore(defaults: defaults)
        XCTAssertEqual(store.scenes, DefaultScenes.all)
        XCTAssertTrue(store.recoveredFromCorruptData)
    }

    func testRecoveryIsReportedOnlyOnce() {
        defaults.set("乱码乱码", forKey: SceneStore.scenesKey)
        _ = SceneStore(defaults: defaults)
        XCTAssertFalse(SceneStore(defaults: defaults).recoveredFromCorruptData)
    }

    func testRecoveryResetsSelectedScene() {
        defaults.set("meeting", forKey: SceneStore.selectedSceneKey)
        defaults.set("乱码乱码", forKey: SceneStore.scenesKey)
        XCTAssertEqual(SceneStore(defaults: defaults).selectedScene?.id, "ai-work")
    }

    func testSavedScenesCarryAVersion() throws {
        SceneStore(defaults: defaults).setApp(calculator, kept: true, inSceneID: "ai-work")
        let data = try XCTUnwrap(defaults.data(forKey: SceneStore.scenesKey))
        let saved = try JSONDecoder().decode(SceneStore.SavedScenes.self, from: data)
        XCTAssertEqual(saved.version, SceneStore.currentVersion)
    }

    func testScenesSavedBeforeVersioningAreKeptAndUpgraded() throws {
        var edited = DefaultScenes.all
        edited[0].keptBundleIDs.append(calculator)
        defaults.set(try JSONEncoder().encode(edited), forKey: SceneStore.scenesKey)

        let store = SceneStore(defaults: defaults)
        XCTAssertEqual(store.scenes, edited)
        XCTAssertFalse(store.recoveredFromCorruptData)

        let data = try XCTUnwrap(defaults.data(forKey: SceneStore.scenesKey))
        let saved = try JSONDecoder().decode(SceneStore.SavedScenes.self, from: data)
        XCTAssertEqual(saved.version, SceneStore.currentVersion)
        XCTAssertEqual(saved.scenes, edited)
    }

    func testScenesFromAnUnknownNewerVersionFallBackToDefaults() throws {
        let future = SceneStore.SavedScenes(version: SceneStore.currentVersion + 1, scenes: DefaultScenes.all)
        defaults.set(try JSONEncoder().encode(future), forKey: SceneStore.scenesKey)
        XCTAssertTrue(SceneStore(defaults: defaults).recoveredFromCorruptData)
    }
}
