import Foundation

/// Pure layout calculation for the split detail view.
/// Extracted from SplitDetailView so it can be unit-tested for overlap,
/// clamping, and edge cases.
public struct SplitLayout {
    /// Width of the draggable divider area (includes space for control buttons).
    public static let dividerWidth: CGFloat = 40

    /// Minimum width for either pane.
    public static let minPaneWidth: CGFloat = 250

    /// Minimum total width needed to fit both panes + divider.
    public static var minTotalWidth: CGFloat {
        minPaneWidth * 2 + dividerWidth
    }

    public let leftWidth: CGFloat
    public let rightWidth: CGFloat
    public let totalWidth: CGFloat

    /// Compute layout for a given total width, split ratio, and drag offset.
    ///
    /// - Parameters:
    ///   - totalWidth: The full container width.
    ///   - splitRatio: 0.0–1.0 ratio for the left pane.
    ///   - dragOffset: Transient pixel offset during drag (0 when idle).
    /// - Returns: A `SplitLayout` with non-overlapping widths that sum correctly.
    public init(totalWidth: CGFloat, splitRatio: Double, dragOffset: CGFloat = 0) {
        self.totalWidth = totalWidth
        let usable = totalWidth - Self.dividerWidth
        let rawLeft = usable * CGFloat(splitRatio) + dragOffset
        let clampedLeft = min(max(rawLeft, Self.minPaneWidth), usable - Self.minPaneWidth)
        self.leftWidth = clampedLeft
        self.rightWidth = usable - clampedLeft
    }

    /// The sum of all three regions. Must equal `totalWidth` exactly.
    public var layoutTotal: CGFloat {
        leftWidth + Self.dividerWidth + rightWidth
    }

    /// Whether panes overlap (layout total exceeds container).
    public var hasOverlap: Bool {
        abs(layoutTotal - totalWidth) > 0.01
    }

    /// Clamp a new split ratio from a drag end position.
    public static func clampedRatio(currentRatio: Double, dragOffset: CGFloat, totalWidth: CGFloat) -> Double {
        let usable = totalWidth - dividerWidth
        let rawLeft = usable * CGFloat(currentRatio) + dragOffset
        let clampedLeft = min(max(rawLeft, minPaneWidth), usable - minPaneWidth)
        return Double(clampedLeft / usable)
    }
}
