import XCTest
@testable import StrataLib

final class SessionManagerSplitTests: XCTestCase {

    private func makeManager() -> SessionManager {
        SessionManager(forTesting: true)
    }

    // MARK: - Initial State

    func testInitialSplitStateIsOff() {
        let manager = makeManager()
        XCTAssertFalse(manager.isSplitScreen)
        XCTAssertNil(manager.splitSessionID)
        XCTAssertEqual(manager.splitRatio, 0.5)
        XCTAssertNil(manager.splitSession)
    }

    // MARK: - Enter / Exit Split Screen

    func testEnterSplitScreen() {
        let manager = makeManager()
        manager.enterSplitScreen()
        XCTAssertTrue(manager.isSplitScreen)
    }

    func testExitSplitScreen() {
        let manager = makeManager()
        manager.enterSplitScreen()
        manager.exitSplitScreen()
        XCTAssertFalse(manager.isSplitScreen)
    }

    func testEnterSplitScreenIsIdempotent() {
        let manager = makeManager()
        manager.enterSplitScreen()
        manager.enterSplitScreen()
        XCTAssertTrue(manager.isSplitScreen, "Double-enter should still be in split")
    }

    // MARK: - Toggle Split Screen

    func testToggleSplitScreenOn() {
        let manager = makeManager()
        manager.toggleSplitScreen()
        XCTAssertTrue(manager.isSplitScreen)
    }

    func testToggleSplitScreenOff() {
        let manager = makeManager()
        manager.toggleSplitScreen()
        manager.toggleSplitScreen()
        XCTAssertFalse(manager.isSplitScreen)
    }

    // MARK: - Split Session Selection

    func testSelectSplitSession() {
        let manager = makeManager()
        let id = UUID()
        manager.selectSplitSession(id)
        XCTAssertEqual(manager.splitSessionID, id)
    }

    func testSplitSessionResolvesFromSessions() {
        let manager = makeManager()
        let session = TerminalSession(name: "Test Terminal", workingDirectory: "/tmp")
        manager.sessions.append(.terminal(session))
        manager.splitSessionID = session.id
        XCTAssertNotNil(manager.splitSession)
        XCTAssertEqual(manager.splitSession?.id, session.id)
    }

    func testSplitSessionReturnsNilForMissingID() {
        let manager = makeManager()
        manager.splitSessionID = UUID() // ID not in sessions array
        XCTAssertNil(manager.splitSession)
    }

    func testSplitSessionReturnsNilWhenNoIDSet() {
        let manager = makeManager()
        XCTAssertNil(manager.splitSession)
    }

    // MARK: - Close Session Clears Split

    func testClosingSplitSessionClearsSplitID() {
        let manager = makeManager()
        let session = TerminalSession(name: "Terminal", workingDirectory: "/tmp")
        let anySession = AnySession.terminal(session)
        manager.sessions.append(anySession)
        manager.splitSessionID = session.id

        manager.closeSession(anySession)

        XCTAssertNil(manager.splitSessionID,
                     "Closing the split session should clear splitSessionID")
    }

    func testClosingNonSplitSessionKeepsSplitID() {
        let manager = makeManager()
        let terminal1 = TerminalSession(name: "Term 1", workingDirectory: "/tmp")
        let terminal2 = TerminalSession(name: "Term 2", workingDirectory: "/tmp")
        manager.sessions.append(.terminal(terminal1))
        manager.sessions.append(.terminal(terminal2))
        manager.splitSessionID = terminal2.id

        manager.closeSession(.terminal(terminal1))

        XCTAssertEqual(manager.splitSessionID, terminal2.id,
                       "Closing a different session should not affect splitSessionID")
    }

    // MARK: - Split Does NOT Auto-Create Sessions

    func testEnterSplitDoesNotCreateSessions() {
        let manager = makeManager()
        let countBefore = manager.sessions.count
        manager.enterSplitScreen()
        XCTAssertEqual(manager.sessions.count, countBefore,
                       "Entering split should not auto-create sessions")
    }

    // MARK: - Split Ratio

    func testSplitRatioDefault() {
        let manager = makeManager()
        XCTAssertEqual(manager.splitRatio, 0.5)
    }

    func testSplitRatioCanBeChanged() {
        let manager = makeManager()
        manager.splitRatio = 0.7
        XCTAssertEqual(manager.splitRatio, 0.7)
    }

    // MARK: - Same Session Cannot Be Both Panes

    func testSplitSessionDifferentFromSelected() {
        let manager = makeManager()
        let terminal1 = TerminalSession(name: "Term 1", workingDirectory: "/tmp")
        let terminal2 = TerminalSession(name: "Term 2", workingDirectory: "/tmp")
        manager.sessions.append(.terminal(terminal1))
        manager.sessions.append(.terminal(terminal2))
        manager.selectedSessionID = terminal1.id
        manager.splitSessionID = terminal2.id

        XCTAssertNotEqual(manager.selectedSessionID, manager.splitSessionID,
                          "Selected and split sessions should be different")
        XCTAssertEqual(manager.selectedSession?.id, terminal1.id)
        XCTAssertEqual(manager.splitSession?.id, terminal2.id)
    }
}
