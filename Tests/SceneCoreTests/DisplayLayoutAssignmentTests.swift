import XCTest
@testable import SceneCore

final class DisplayLayoutAssignmentTests: XCTestCase {

    // MARK: - Codable roundtrip

    func testCodableRoundTrip() throws {
        let assignment = DisplayLayoutAssignment(
            displayName: "DELL U2723QE",
            layoutID: UUID(uuidString: "11111111-0001-0000-0000-000000000001")!
        )
        let data = try JSONEncoder().encode(assignment)
        let decoded = try JSONDecoder().decode(DisplayLayoutAssignment.self, from: data)
        XCTAssertEqual(decoded, assignment)
    }

    func testArrayCodableRoundTrip() throws {
        let assignments: [DisplayLayoutAssignment] = [
            DisplayLayoutAssignment(displayName: "Built-in Retina Display", layoutID: UUID()),
            DisplayLayoutAssignment(displayName: "LG HDR 4K", layoutID: UUID()),
        ]
        let data = try JSONEncoder().encode(assignments)
        let decoded = try JSONDecoder().decode([DisplayLayoutAssignment].self, from: data)
        XCTAssertEqual(decoded, assignments)
    }

    // MARK: - Equality

    func testEqualityMatchesOnBothFields() {
        let id = UUID()
        let a = DisplayLayoutAssignment(displayName: "Monitor", layoutID: id)
        let b = DisplayLayoutAssignment(displayName: "Monitor", layoutID: id)
        XCTAssertEqual(a, b)
    }

    func testInequalityOnDifferentDisplayName() {
        let id = UUID()
        let a = DisplayLayoutAssignment(displayName: "Monitor A", layoutID: id)
        let b = DisplayLayoutAssignment(displayName: "Monitor B", layoutID: id)
        XCTAssertNotEqual(a, b)
    }

    func testInequalityOnDifferentLayoutID() {
        let a = DisplayLayoutAssignment(displayName: "Monitor", layoutID: UUID())
        let b = DisplayLayoutAssignment(displayName: "Monitor", layoutID: UUID())
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Hashable

    func testHashableInSet() {
        let id = UUID()
        let a = DisplayLayoutAssignment(displayName: "Monitor", layoutID: id)
        let b = DisplayLayoutAssignment(displayName: "Monitor", layoutID: id)
        let set: Set<DisplayLayoutAssignment> = [a, b]
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Workspace.resolvedLayoutID

    func testResolvedLayoutIDReturnsAssignedWhenPresent() {
        let primaryID = UUID()
        let externalID = UUID()
        let workspace = Workspace(
            name: "Test",
            layoutID: primaryID,
            displayLayouts: [
                DisplayLayoutAssignment(displayName: "External", layoutID: externalID)
            ]
        )
        XCTAssertEqual(workspace.resolvedLayoutID(forDisplay: "External"), externalID)
    }

    func testResolvedLayoutIDFallsBackToPrimaryLayoutID() {
        let primaryID = UUID()
        let workspace = Workspace(
            name: "Test",
            layoutID: primaryID,
            displayLayouts: [
                DisplayLayoutAssignment(displayName: "External", layoutID: UUID())
            ]
        )
        XCTAssertEqual(workspace.resolvedLayoutID(forDisplay: "Unknown Monitor"), primaryID)
    }

    func testResolvedLayoutIDWithEmptyDisplayLayouts() {
        let primaryID = UUID()
        let workspace = Workspace(
            name: "Test",
            layoutID: primaryID,
            displayLayouts: []
        )
        XCTAssertEqual(workspace.resolvedLayoutID(forDisplay: "Any"), primaryID)
    }

    // MARK: - Workspace backward-compat decode

    func testWorkspaceDecodesWithoutDisplayLayoutsKey() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "name": "Legacy",
          "layoutID": "22222222-2222-2222-2222-222222222222",
          "appsToLaunch": [],
          "appsToQuit": [],
          "triggers": [],
          "isPresetSeed": false,
          "isModified": false
        }
        """
        let decoded = try JSONDecoder().decode(Workspace.self, from: Data(json.utf8))
        XCTAssertTrue(decoded.displayLayouts.isEmpty)
    }

    func testWorkspaceDecodesWithDisplayLayoutsPresent() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "name": "Multi-Display",
          "layoutID": "22222222-2222-2222-2222-222222222222",
          "appsToLaunch": [],
          "appsToQuit": [],
          "triggers": [],
          "displayLayouts": [
            {"displayName": "DELL U2723QE", "layoutID": "33333333-0001-0000-0000-000000000001"}
          ],
          "isPresetSeed": false,
          "isModified": false
        }
        """
        let decoded = try JSONDecoder().decode(Workspace.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.displayLayouts.count, 1)
        XCTAssertEqual(decoded.displayLayouts[0].displayName, "DELL U2723QE")
        XCTAssertEqual(
            decoded.displayLayouts[0].layoutID,
            UUID(uuidString: "33333333-0001-0000-0000-000000000001")!
        )
    }

    func testWorkspaceWithDisplayLayoutsRoundTrip() throws {
        let original = Workspace(
            name: "Studio",
            layoutID: UUID(),
            displayLayouts: [
                DisplayLayoutAssignment(displayName: "Built-in", layoutID: UUID()),
                DisplayLayoutAssignment(displayName: "External 4K", layoutID: UUID()),
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Workspace.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.displayLayouts.count, 2)
    }

    // MARK: - Equatable with displayLayouts

    func testWorkspaceEqualityDiffersOnDisplayLayouts() {
        let layoutA = UUID()
        let layoutB = UUID()
        let base = Workspace(name: "Test", layoutID: UUID(), displayLayouts: [])
        var modified = base
        modified.displayLayouts = [DisplayLayoutAssignment(displayName: "X", layoutID: layoutA)]
        XCTAssertNotEqual(base, modified)

        var modified2 = modified
        modified2.displayLayouts[0].layoutID = layoutB
        XCTAssertNotEqual(modified, modified2)
    }
}
