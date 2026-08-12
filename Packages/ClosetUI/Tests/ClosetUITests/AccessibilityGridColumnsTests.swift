import Testing
import SwiftUI
@testable import ClosetUI

struct AccessibilityGridColumnsTests {
    @Test func stacksToOneColumnAtAccessibilityTypeSizes() {
        #expect(AccessibilityGridColumns.count(for: .large, regular: 3) == 3)
        #expect(AccessibilityGridColumns.count(for: .xxxLarge, regular: 3) == 3)
        #expect(AccessibilityGridColumns.count(for: .accessibility1, regular: 3) == 1)
        #expect(AccessibilityGridColumns.count(for: .accessibility5, regular: 2) == 1)
    }

    @Test func adaptiveItemsStayNonEmptyAndStackFlagMatchesThreshold() {
        #expect(!AccessibilityGridColumns.isStacked(.xxxLarge))
        #expect(AccessibilityGridColumns.isStacked(.accessibility1))
        #expect(!AccessibilityGridColumns.items(
            for: .large, regularMinimum: 104, spacing: 12).isEmpty)
        #expect(AccessibilityGridColumns.items(
            for: .accessibility1, regularMinimum: 104, spacing: 12).count == 1)
    }

    @Test func fixedCountItemsCollapseToOne() {
        let three = AccessibilityGridColumns.items(
            for: .large, regularCount: 3, spacing: 12)
        #expect(three.count == 3)
        let one = AccessibilityGridColumns.items(
            for: .accessibility3, regularCount: 3, spacing: 12)
        #expect(one.count == 1)
    }
}
