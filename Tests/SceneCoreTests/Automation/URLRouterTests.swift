import XCTest
@testable import SceneCore

final class URLRouterTests: XCTestCase {

    // MARK: - Activate workspace

    func testParse_workspaceByName() {
        let url = URL(string: "scene://workspace/Coding")!
        let result = URLRouter.parse(url)
        XCTAssertEqual(result, .success(.activateWorkspace(id: .name("Coding"), force: false)))
    }

    func testParse_workspaceByUUID() {
        let id = UUID()
        let url = URL(string: "scene://workspace/\(id.uuidString)")!
        let result = URLRouter.parse(url)
        XCTAssertEqual(result, .success(.activateWorkspace(id: .uuid(id), force: false)))
    }

    func testParse_workspacePercentEncodedName() {
        let url = URL(string: "scene://workspace/Friday%20review")!
        let result = URLRouter.parse(url)
        XCTAssertEqual(result, .success(.activateWorkspace(id: .name("Friday review"), force: false)))
    }

    func testParse_workspaceForceQuery() {
        let url = URL(string: "scene://workspace/Coding?force=1")!
        let result = URLRouter.parse(url)
        XCTAssertEqual(result, .success(.activateWorkspace(id: .name("Coding"), force: true)))
    }

    // MARK: - Apply layout

    func testParse_layoutByName_withScreenQuery() {
        let url = URL(string: "scene://layout/Halves?screen=primary")!
        let result = URLRouter.parse(url)
        XCTAssertEqual(result, .success(.applyLayout(id: .name("Halves"), force: false, screen: .primary)))
    }

    func testParse_layoutScreenIndex() {
        let url = URL(string: "scene://layout/Quads?screen=1")!
        let result = URLRouter.parse(url)
        XCTAssertEqual(result, .success(.applyLayout(id: .name("Quads"), force: false, screen: .index(1))))
    }

    // MARK: - Free mode

    func testParse_freeModeToggle() {
        let url = URL(string: "scene://free-mode/toggle")!
        XCTAssertEqual(URLRouter.parse(url), .success(.toggleFreeMode))
    }

    func testParse_freeModeOnOff() {
        XCTAssertEqual(
            URLRouter.parse(URL(string: "scene://free-mode/on")!),
            .success(.setFreeMode(enabled: true))
        )
        XCTAssertEqual(
            URLRouter.parse(URL(string: "scene://free-mode/off")!),
            .success(.setFreeMode(enabled: false))
        )
    }

    // MARK: - Errors

    func testParse_unsupportedScheme() {
        let url = URL(string: "https://workspace/Coding")!
        XCTAssertEqual(URLRouter.parse(url), .failure(.unsupportedScheme))
    }

    func testParse_unknownRoute() {
        let url = URL(string: "scene://nope/x")!
        XCTAssertEqual(URLRouter.parse(url), .failure(.unknownRoute))
    }

    func testParse_missingIdentifier() {
        let url = URL(string: "scene://workspace")!
        XCTAssertEqual(URLRouter.parse(url), .failure(.missingIdentifier))
    }

    // MARK: - Forward-compat

    func testParse_unknownQueryKeyIgnored() {
        let url = URL(string: "scene://workspace/Coding?force=1&unknown=foo")!
        let result = URLRouter.parse(url)
        XCTAssertEqual(result, .success(.activateWorkspace(id: .name("Coding"), force: true)))
    }
}
