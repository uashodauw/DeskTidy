import XCTest
@testable import DeskTidyCore

final class SceneEditingTests: XCTestCase {
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

    // MARK: - 名字规则

    func testBlankNameIsRejected() {
        XCTAssertEqual(SceneEditing.problem(with: "   ", among: []), .empty)
    }

    func testTooLongNameIsRejected() {
        XCTAssertEqual(SceneEditing.problem(with: "一二三四五六七八九", among: []), .tooLong)
        XCTAssertNil(SceneEditing.problem(with: "一二三四五六七八", among: []))
    }

    func testDuplicateNameIsRejectedAfterTrimming() {
        XCTAssertEqual(SceneEditing.problem(with: " 开会 ", among: DefaultScenes.all), .duplicate)
    }

    func testRenamingToOwnNameIsAllowed() {
        XCTAssertNil(SceneEditing.problem(with: "开会", among: DefaultScenes.all, renamingID: "meeting"))
    }

    // MARK: - 新建

    func testAddedSceneStartsEmptyAndIsSaved() throws {
        let store = SceneStore(defaults: defaults)
        let scene = try XCTUnwrap(store.addScene(named: "  写作 "))
        XCTAssertEqual(scene.name, "写作")
        XCTAssertEqual(scene.keptBundleIDs, [])
        XCTAssertEqual(SceneStore(defaults: defaults).scenes.last, scene)
    }

    func testAddedScenesGetDistinctIDs() throws {
        let store = SceneStore(defaults: defaults)
        let a = try XCTUnwrap(store.addScene(named: "写作"))
        let b = try XCTUnwrap(store.addScene(named: "剪视频"))
        XCTAssertNotEqual(a.id, b.id)
    }

    func testInvalidNameAddsNothing() {
        let store = SceneStore(defaults: defaults)
        XCTAssertNil(store.addScene(named: "开会"))
        XCTAssertNil(store.addScene(named: ""))
        XCTAssertEqual(store.scenes, DefaultScenes.all)
    }

    func testCannotAddBeyondTheLimit() {
        let store = SceneStore(defaults: defaults)
        for i in 0..<(SceneEditing.maxScenes - DefaultScenes.all.count) {
            XCTAssertNotNil(store.addScene(named: "场景\(i)"))
        }
        XCTAssertFalse(store.canAddScene)
        XCTAssertNil(store.addScene(named: "再来一个"))
        XCTAssertEqual(store.scenes.count, SceneEditing.maxScenes)
    }

    func testNewSceneCanKeepApps() throws {
        let store = SceneStore(defaults: defaults)
        let scene = try XCTUnwrap(store.addScene(named: "写作"))
        store.setApp("com.apple.Notes", kept: true, inSceneID: scene.id)
        XCTAssertEqual(SceneStore(defaults: defaults).scenes.last?.keptBundleIDs, ["com.apple.Notes"])
    }

    // MARK: - 改名

    func testRenameKeepsAppsAndIsSaved() {
        let store = SceneStore(defaults: defaults)
        XCTAssertTrue(store.renameScene(id: "meeting", to: "视频会议"))
        let renamed = SceneStore(defaults: defaults).scenes.first { $0.id == "meeting" }
        XCTAssertEqual(renamed?.name, "视频会议")
        XCTAssertEqual(renamed?.keptBundleIDs, DefaultScenes.all[2].keptBundleIDs)
    }

    func testInvalidRenameChangesNothing() {
        let store = SceneStore(defaults: defaults)
        XCTAssertFalse(store.renameScene(id: "meeting", to: "做设计"))
        XCTAssertFalse(store.renameScene(id: "meeting", to: " "))
        XCTAssertFalse(store.renameScene(id: "nope", to: "随便"))
        XCTAssertEqual(store.scenes, DefaultScenes.all)
    }

    // MARK: - 删除

    func testDeleteRemovesSceneAndIsSaved() {
        let store = SceneStore(defaults: defaults)
        XCTAssertTrue(store.deleteScene(id: "design"))
        XCTAssertEqual(SceneStore(defaults: defaults).scenes.map(\.id), ["ai-work", "meeting"])
    }

    func testDeletingTheSelectedSceneSwitchesToNoScene() {
        let store = SceneStore(defaults: defaults)
        store.select(sceneID: "design")
        store.deleteScene(id: "design")
        XCTAssertNil(store.selectedScene)
        XCTAssertEqual(store.keptBundleIDs, [])
    }

    func testDeletingAnotherSceneKeepsSelection() {
        let store = SceneStore(defaults: defaults)
        store.select(sceneID: "meeting")
        store.deleteScene(id: "design")
        XCTAssertEqual(store.selectedScene?.id, "meeting")
    }

    func testLastSceneCannotBeDeleted() {
        let store = SceneStore(defaults: defaults)
        XCTAssertTrue(store.deleteScene(id: "ai-work"))
        XCTAssertTrue(store.deleteScene(id: "design"))
        XCTAssertFalse(store.canDeleteScene)
        XCTAssertFalse(store.deleteScene(id: "meeting"))
        XCTAssertEqual(SceneStore(defaults: defaults).scenes.map(\.id), ["meeting"])
    }
}
