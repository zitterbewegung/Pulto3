import XCTest
@testable import Pulto

final class TeapotDemoWorkspaceTests: XCTestCase {

    @MainActor
    func testDemoWorkspaceCreatedOnce() async throws {
        let wm = WorkspaceManager.shared

        // Ensure idempotency
        await wm.ensureTeapotDemoProjectExists()
        let countAfterFirst = wm.workspaces.filter { $0.name == "Teapot IoT Demo" }.count

        await wm.ensureTeapotDemoProjectExists()
        let countAfterSecond = wm.workspaces.filter { $0.name == "Teapot IoT Demo" }.count

        XCTAssertEqual(countAfterFirst, 1, "Demo should be created once")
        XCTAssertEqual(countAfterSecond, 1, "Demo creation should be idempotent")
    }

    @MainActor
    func testDemoWorkspaceImportable() async throws {
        let wm = WorkspaceManager.shared
        await wm.ensureTeapotDemoProjectExists()

        guard let demo = wm.workspaces.first(where: { $0.name == "Teapot IoT Demo" }) else {
            XCTFail("Demo workspace not found")
            return
        }
        guard let url = demo.fileURL else {
            XCTFail("Demo workspace file URL missing")
            return
        }

        let windowManager = WindowTypeManager.shared
        await windowManager.clearAllWindowsAsync()

        let importResult = try windowManager.importFromGenericNotebook(fileURL: url)
        XCTAssertEqual(importResult.restoredWindows.count, 4, "Should restore 4 demo windows")

        let types = Set(importResult.restoredWindows.map { $0.windowType.rawValue })
        XCTAssertTrue(types.contains("column"))
        XCTAssertTrue(types.contains("model3d"))
        XCTAssertTrue(types.contains("pointcloud"))
        XCTAssertTrue(types.contains("volume"))
    }
}