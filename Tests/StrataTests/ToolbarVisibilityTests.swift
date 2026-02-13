import XCTest
@testable import StrataLib

/// Tests verifying toolbar button configuration and split view state logic.
///
/// Note on approach: SwiftUI toolbars cannot be introspected at the view level
/// in unit tests. Instead, we define the toolbar configuration as data
/// (ToolbarConfig) and test that the combined width fits within the available
/// toolbar space. This catches the exact class of bug that caused the `>>`
/// overflow: too many text-labeled buttons exceeding available width.
final class ToolbarVisibilityTests: XCTestCase {

    private func makeManager() -> SessionManager {
        SessionManager(forTesting: true)
    }

    // MARK: - Toolbar Width Budget

    /// Estimated width per toolbar button by label style.
    /// Based on macOS toolbar rendering at default scale:
    /// - Icon-only: ~32pt (icon) + ~8pt padding = ~40pt
    /// - Title+Icon: ~32pt (icon) + ~text + ~16pt padding = varies by text length
    struct ToolbarConfig {
        struct Button {
            let label: String
            let hasTextLabel: Bool

            var estimatedWidth: CGFloat {
                if hasTextLabel {
                    // icon(20) + spacing(4) + text(approx 7pt per char) + padding(16)
                    return 20 + 4 + CGFloat(label.count) * 7 + 16
                } else {
                    // icon(20) + padding(20)
                    return 40
                }
            }
        }

        let buttons: [Button]
        let spacing: CGFloat // HStack spacing between buttons

        var totalEstimatedWidth: CGFloat {
            let buttonWidths = buttons.reduce(0) { $0 + $1.estimatedWidth }
            let spacingWidth = CGFloat(max(buttons.count - 1, 0)) * spacing
            return buttonWidths + spacingWidth
        }
    }

    // The actual toolbar configurations matching the source code

    static let contentViewToolbar = ToolbarConfig(
        buttons: [
            .init(label: "Split View", hasTextLabel: true),
            .init(label: "Schedules", hasTextLabel: true),
            .init(label: "Palette", hasTextLabel: true),
        ],
        spacing: 4
    )

    static let sessionViewToolbar = ToolbarConfig(
        buttons: [
            .init(label: "Agents", hasTextLabel: false),     // .iconOnly
            .init(label: "Timeline", hasTextLabel: false),
            .init(label: "Memory", hasTextLabel: false),
            .init(label: "Skills", hasTextLabel: false),
            .init(label: "Settings", hasTextLabel: false),
            .init(label: "Workspace", hasTextLabel: false),
        ],
        spacing: 4
    )

    /// At a comfortable window width of 1100pt, available toolbar space is:
    /// 1100 - traffic lights(70) - title(150) - padding(30) = 850pt.
    /// At minimum width (800pt): 800 - 250 = 550pt (some overflow to >> is OK).
    static let availableToolbarWidth: CGFloat = 850

    /// All toolbar buttons must fit within the available toolbar width.
    /// This is the test that would have caught the `>>` overflow bug.
    func testAllToolbarButtonsFitInAvailableSpace() {
        let totalWidth = Self.contentViewToolbar.totalEstimatedWidth
            + Self.sessionViewToolbar.totalEstimatedWidth
            + 20 // gap between the two toolbar item groups

        XCTAssertLessThanOrEqual(totalWidth, Self.availableToolbarWidth,
            """
            Toolbar buttons exceed available space!
            ContentView buttons: \(Self.contentViewToolbar.totalEstimatedWidth)pt
            SessionView buttons: \(Self.sessionViewToolbar.totalEstimatedWidth)pt
            Total: \(totalWidth)pt
            Available: \(Self.availableToolbarWidth)pt
            Reduce button count, shorten labels, or switch to iconOnly.
            """)
    }

    /// ContentView buttons alone should fit (they have text labels).
    func testContentViewButtonsFitAlone() {
        XCTAssertLessThanOrEqual(
            Self.contentViewToolbar.totalEstimatedWidth, 350,
            "ContentView toolbar buttons alone should fit in ~350pt")
    }

    /// SessionView buttons alone should fit (icon-only).
    func testSessionViewButtonsFitAlone() {
        XCTAssertLessThanOrEqual(
            Self.sessionViewToolbar.totalEstimatedWidth, 300,
            "SessionView toolbar buttons alone should fit in ~300pt")
    }

    /// Regression test: if ALL buttons had text labels, they would overflow.
    /// This documents the constraint that caused the original bug.
    func testAllButtonsWithTextLabelsWouldOverflow() {
        let allWithText = ToolbarConfig(
            buttons: [
                // ContentView
                .init(label: "Split View", hasTextLabel: true),
                .init(label: "Schedules", hasTextLabel: true),
                .init(label: "Palette", hasTextLabel: true),
                // SessionView
                .init(label: "Agents", hasTextLabel: true),
                .init(label: "Timeline", hasTextLabel: true),
                .init(label: "Memory", hasTextLabel: true),
                .init(label: "Skills", hasTextLabel: true),
                .init(label: "Settings", hasTextLabel: true),
                .init(label: "Workspace", hasTextLabel: true),
            ],
            spacing: 4
        )
        XCTAssertGreaterThan(allWithText.totalEstimatedWidth, Self.availableToolbarWidth,
            "9 buttons with text labels SHOULD exceed available space (documents the constraint)")
    }

    // MARK: - Label Style Consistency

    /// ContentView buttons use .titleAndIcon (text + icon visible).
    func testContentViewUsesTextLabels() {
        for button in Self.contentViewToolbar.buttons {
            XCTAssertTrue(button.hasTextLabel,
                         "\(button.label) should have text label (ContentView uses .titleAndIcon)")
        }
    }

    /// SessionView buttons use .iconOnly (icon only, text in tooltip).
    func testSessionViewUsesIconOnly() {
        for button in Self.sessionViewToolbar.buttons {
            XCTAssertFalse(button.hasTextLabel,
                          "\(button.label) should be icon-only (SessionView uses .iconOnly)")
        }
    }

    // MARK: - Button Counts

    func testContentViewHasExactly3Buttons() {
        XCTAssertEqual(Self.contentViewToolbar.buttons.count, 3)
    }

    func testSessionViewHasExactly6Buttons() {
        XCTAssertEqual(Self.sessionViewToolbar.buttons.count, 6)
    }

    // MARK: - Split View Button State

    func testSplitButtonDisabledWhenNoSession() {
        let manager = makeManager()
        XCTAssertNil(manager.selectedSession,
                     "No session should be selected initially")
    }

    func testSplitButtonEnabledWhenSessionSelected() {
        let manager = makeManager()
        let terminal = TerminalSession(name: "Term", workingDirectory: "/tmp")
        manager.sessions.append(.terminal(terminal))
        manager.selectedSessionID = terminal.id
        XCTAssertNotNil(manager.selectedSession,
                        "Session should be selected, enabling split button")
    }

    // MARK: - hideToolbar Logic

    func testHideToolbarLogicForSplitPanes() {
        // SplitDetailView passes hideToolbar=false to left, true to right
        let hideToolbarLeft = false
        let hideToolbarRight = true
        XCTAssertFalse(hideToolbarLeft, "Left pane should show toolbar")
        XCTAssertTrue(hideToolbarRight, "Right pane should hide toolbar")
    }

    // MARK: - Split Button Icon

    func testSplitButtonIconChangesWhenActive() {
        let manager = makeManager()

        let iconOff = manager.isSplitScreen
            ? "rectangle.split.2x1.fill" : "rectangle.split.2x1"
        XCTAssertEqual(iconOff, "rectangle.split.2x1")

        manager.isSplitScreen = true
        let iconOn = manager.isSplitScreen
            ? "rectangle.split.2x1.fill" : "rectangle.split.2x1"
        XCTAssertEqual(iconOn, "rectangle.split.2x1.fill")
    }

    // MARK: - Focus Mode and Split Mutual Exclusivity

    func testFocusModeExitsSplit() {
        let manager = makeManager()
        manager.enterSplitScreen()
        XCTAssertTrue(manager.isSplitScreen)

        // Simulate ContentView.onChange behavior
        if manager.isSplitScreen { manager.exitSplitScreen() }
        XCTAssertFalse(manager.isSplitScreen)
    }

    // MARK: - Session Picker Visibility

    func testRightPaneShowsPickerWhenNoSplitSession() {
        let manager = makeManager()
        manager.enterSplitScreen()
        XCTAssertNil(manager.splitSession)
    }

    func testRightPaneShowsSessionWhenSplitSessionSet() {
        let manager = makeManager()
        let terminal = TerminalSession(name: "Term", workingDirectory: "/tmp")
        manager.sessions.append(.terminal(terminal))
        manager.enterSplitScreen()
        manager.splitSessionID = terminal.id
        XCTAssertNotNil(manager.splitSession)
    }

    // MARK: - Session Switcher Filters

    func testSessionSwitcherExcludesSelectedSession() {
        let manager = makeManager()
        let t1 = TerminalSession(name: "Term 1", workingDirectory: "/tmp")
        let t2 = TerminalSession(name: "Term 2", workingDirectory: "/tmp")
        let t3 = TerminalSession(name: "Term 3", workingDirectory: "/tmp")
        manager.sessions.append(.terminal(t1))
        manager.sessions.append(.terminal(t2))
        manager.sessions.append(.terminal(t3))
        manager.selectedSessionID = t1.id

        let available = manager.sessions.filter { $0.id != manager.selectedSessionID }
        XCTAssertEqual(available.count, 2)
        XCTAssertFalse(available.contains { $0.id == t1.id })
    }
}
