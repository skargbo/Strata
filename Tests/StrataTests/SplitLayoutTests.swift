import XCTest
@testable import StrataLib

final class SplitLayoutTests: XCTestCase {

    // MARK: - No Overlap (the bug that triggered these tests)

    /// The sum of left + divider + right must equal totalWidth exactly.
    /// This was broken when dividerWidth=24 but the ZStack was 40pt wide.
    func testNoOverlapAtDefaultRatio() {
        let layout = SplitLayout(totalWidth: 1100, splitRatio: 0.5)
        XCTAssertFalse(layout.hasOverlap, "Layout should not overlap at default ratio")
        XCTAssertEqual(layout.layoutTotal, layout.totalWidth, accuracy: 0.01,
                       "left + divider + right must equal totalWidth")
    }

    func testNoOverlapAtExtremeLeftRatio() {
        let layout = SplitLayout(totalWidth: 1100, splitRatio: 0.0)
        XCTAssertFalse(layout.hasOverlap)
        XCTAssertEqual(layout.layoutTotal, layout.totalWidth, accuracy: 0.01)
    }

    func testNoOverlapAtExtremeRightRatio() {
        let layout = SplitLayout(totalWidth: 1100, splitRatio: 1.0)
        XCTAssertFalse(layout.hasOverlap)
        XCTAssertEqual(layout.layoutTotal, layout.totalWidth, accuracy: 0.01)
    }

    func testNoOverlapAcrossManyRatios() {
        for ratio in stride(from: 0.0, through: 1.0, by: 0.05) {
            let layout = SplitLayout(totalWidth: 1100, splitRatio: ratio)
            XCTAssertFalse(layout.hasOverlap,
                          "Overlap detected at ratio \(ratio): total=\(layout.layoutTotal), expected=\(layout.totalWidth)")
            XCTAssertEqual(layout.layoutTotal, layout.totalWidth, accuracy: 0.01,
                          "Sum mismatch at ratio \(ratio)")
        }
    }

    func testNoOverlapAcrossMultipleWindowWidths() {
        let widths: [CGFloat] = [540, 800, 1000, 1100, 1400, 1920, 2560]
        for width in widths {
            let layout = SplitLayout(totalWidth: width, splitRatio: 0.5)
            XCTAssertFalse(layout.hasOverlap,
                          "Overlap at width \(width): total=\(layout.layoutTotal)")
        }
    }

    func testNoOverlapWithDragOffset() {
        let offsets: [CGFloat] = [-200, -100, -50, 0, 50, 100, 200]
        for offset in offsets {
            let layout = SplitLayout(totalWidth: 1100, splitRatio: 0.5, dragOffset: offset)
            XCTAssertFalse(layout.hasOverlap,
                          "Overlap with drag offset \(offset)")
            XCTAssertEqual(layout.layoutTotal, layout.totalWidth, accuracy: 0.01)
        }
    }

    // MARK: - Minimum Pane Width Clamping

    func testLeftPaneNeverBelowMinimum() {
        let layout = SplitLayout(totalWidth: 1100, splitRatio: 0.0)
        XCTAssertGreaterThanOrEqual(layout.leftWidth, SplitLayout.minPaneWidth,
                                     "Left pane should not go below minimum")
    }

    func testRightPaneNeverBelowMinimum() {
        let layout = SplitLayout(totalWidth: 1100, splitRatio: 1.0)
        XCTAssertGreaterThanOrEqual(layout.rightWidth, SplitLayout.minPaneWidth,
                                     "Right pane should not go below minimum")
    }

    func testBothPanesAboveMinimumWithLargeDrag() {
        let layout = SplitLayout(totalWidth: 1100, splitRatio: 0.5, dragOffset: 500)
        XCTAssertGreaterThanOrEqual(layout.leftWidth, SplitLayout.minPaneWidth)
        XCTAssertGreaterThanOrEqual(layout.rightWidth, SplitLayout.minPaneWidth)
    }

    func testBothPanesAboveMinimumWithNegativeDrag() {
        let layout = SplitLayout(totalWidth: 1100, splitRatio: 0.5, dragOffset: -500)
        XCTAssertGreaterThanOrEqual(layout.leftWidth, SplitLayout.minPaneWidth)
        XCTAssertGreaterThanOrEqual(layout.rightWidth, SplitLayout.minPaneWidth)
    }

    // MARK: - Pane Width Positivity

    func testPaneWidthsArePositive() {
        for ratio in stride(from: 0.0, through: 1.0, by: 0.1) {
            let layout = SplitLayout(totalWidth: 1100, splitRatio: ratio)
            XCTAssertGreaterThan(layout.leftWidth, 0, "Left width must be positive at ratio \(ratio)")
            XCTAssertGreaterThan(layout.rightWidth, 0, "Right width must be positive at ratio \(ratio)")
        }
    }

    // MARK: - Divider Width Constant

    func testDividerWidthIsReasonable() {
        // Divider should be wide enough for buttons but not excessive
        XCTAssertGreaterThanOrEqual(SplitLayout.dividerWidth, 20,
                                     "Divider too narrow for buttons")
        XCTAssertLessThanOrEqual(SplitLayout.dividerWidth, 60,
                                  "Divider unreasonably wide")
    }

    // MARK: - Minimum Total Width

    func testMinTotalWidthFitsBothPanes() {
        let layout = SplitLayout(totalWidth: SplitLayout.minTotalWidth, splitRatio: 0.5)
        XCTAssertGreaterThanOrEqual(layout.leftWidth, SplitLayout.minPaneWidth)
        XCTAssertGreaterThanOrEqual(layout.rightWidth, SplitLayout.minPaneWidth)
        XCTAssertFalse(layout.hasOverlap)
    }

    // MARK: - Clamped Ratio

    func testClampedRatioStaysInBounds() {
        let ratio = SplitLayout.clampedRatio(currentRatio: 0.5, dragOffset: 1000, totalWidth: 1100)
        XCTAssertGreaterThanOrEqual(ratio, 0.0)
        XCTAssertLessThanOrEqual(ratio, 1.0)
    }

    func testClampedRatioWithNegativeDrag() {
        let ratio = SplitLayout.clampedRatio(currentRatio: 0.5, dragOffset: -1000, totalWidth: 1100)
        XCTAssertGreaterThanOrEqual(ratio, 0.0)
        XCTAssertLessThanOrEqual(ratio, 1.0)
    }

    func testClampedRatioPreservesMinimumPanes() {
        let ratio = SplitLayout.clampedRatio(currentRatio: 0.5, dragOffset: 500, totalWidth: 1100)
        let layout = SplitLayout(totalWidth: 1100, splitRatio: ratio)
        XCTAssertGreaterThanOrEqual(layout.leftWidth, SplitLayout.minPaneWidth)
        XCTAssertGreaterThanOrEqual(layout.rightWidth, SplitLayout.minPaneWidth)
    }

    // MARK: - Default Ratio Produces Equal Panes

    func testDefaultRatioProducesEqualPanes() {
        let layout = SplitLayout(totalWidth: 1100, splitRatio: 0.5)
        XCTAssertEqual(layout.leftWidth, layout.rightWidth, accuracy: 1.0,
                       "50/50 ratio should produce roughly equal panes")
    }
}
