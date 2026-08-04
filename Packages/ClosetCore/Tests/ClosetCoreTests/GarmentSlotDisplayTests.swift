import Testing
@testable import ClosetCore

struct GarmentSlotDisplayTests {
    @Test func displayTitlesAreHumanReadable() {
        for slot in GarmentSlot.allCases {
            #expect(!slot.displayTitle.isEmpty)
            #expect(slot.displayTitle != slot.rawValue) // Title Case, not raw enum string
            #expect(slot.displayTitle.first?.isUppercase == true)
            #expect(!slot.displayTitle.contains("_"))
        }
        #expect(GarmentSlot.top.displayTitle == "Top")
        #expect(GarmentSlot.outerwear.displayTitle == "Outerwear")
        #expect(GarmentSlot.accessory.displayTitle == "Accessory")
    }

    @Test func systemImagesAreDistinctAndNonEmpty() {
        let names = GarmentSlot.allCases.map(\.systemImageName)
        #expect(names.allSatisfy { !$0.isEmpty })
        #expect(Set(names).count == names.count)
        #expect(GarmentSlot.top.systemImageName.contains("tshirt"))
        #expect(GarmentSlot.shoes.systemImageName.contains("shoe"))
    }

    @Test func resolvedMapsUnknownToTop() {
        #expect(GarmentSlot.resolved("dress") == .dress)
        #expect(GarmentSlot.resolved("nope") == .top)
        #expect(GarmentSlot.resolved("") == .top)
    }
}
