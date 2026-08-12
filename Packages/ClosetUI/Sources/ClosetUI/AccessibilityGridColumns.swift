import SwiftUI

/// Largest accessibility type sizes collapse product grids to one stacked column
/// (DESIGN §10.4). Closet + feature grids share this helper so the threshold
/// cannot drift per screen.
public enum AccessibilityGridColumns {
    public static let stackFrom: DynamicTypeSize = .accessibility1

    public static func isStacked(_ size: DynamicTypeSize) -> Bool {
        size >= stackFrom
    }

    public static func count(for size: DynamicTypeSize, regular: Int) -> Int {
        isStacked(size) ? 1 : max(1, regular)
    }

    public static func items(
        for size: DynamicTypeSize,
        regularMinimum: CGFloat,
        spacing: CGFloat
    ) -> [GridItem] {
        if isStacked(size) {
            return [GridItem(.flexible())]
        }
        return [GridItem(.adaptive(minimum: regularMinimum), spacing: spacing)]
    }

    public static func items(
        for size: DynamicTypeSize,
        regularCount: Int,
        spacing: CGFloat
    ) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible()),
            count: count(for: size, regular: regularCount))
    }
}
