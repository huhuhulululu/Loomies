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

    @Test func resolvedAlignsWithDisplaySlotForDirtyLabels() {
        // 列表/缩略图 Type 文案与纸娃娃叠衣同真相
        #expect(GarmentSlot.resolved("top", name: "Navy Blazer") == .outerwear)
        #expect(GarmentSlot.resolved("top", name: "Black bomber") == .outerwear)
        #expect(GarmentSlot.resolved("bomber") == .outerwear)
        #expect(GarmentSlot.resolved("top", name: "White tee") == .top)
        #expect(GarmentSlot.resolved("accessory", name: "Belt") == .accessory)
        #expect(GarmentSlot.resolved("jeans") == .bottom)
        // 牛津纺衬衫不得被纠成 shoes
        #expect(GarmentSlot.resolved("top", name: "Oxford Shirt") == .top)
        #expect(GarmentSlot.resolved("top", name: "Brown oxfords") == .shoes)
    }
}
