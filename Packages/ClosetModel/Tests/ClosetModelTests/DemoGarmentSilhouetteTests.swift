import Testing
import Foundation
import ClosetCore
@testable import ClosetModel

struct DemoGarmentSilhouetteTests {

    @Test func pngForEverySlotIsNonEmpty() {
        for slot in BodyAvatarSlot.allCases {
            let data = DemoGarmentSilhouette.pngData(
                slot: slot, name: "Sample \(slot.rawValue)", hue: 200, isNeutral: false)
            #expect(data != nil)
            #expect((data?.count ?? 0) > 200)
            // PNG magic
            #expect(data?.starts(with: [0x89, 0x50, 0x4E, 0x47]) == true)
        }
    }

    @Test func namedColorsDifferFromNeutralGray() {
        let white = DemoGarmentSilhouette.pngData(
            slot: .top, name: "White tee", hue: 0, isNeutral: true)
        let navy = DemoGarmentSilhouette.pngData(
            slot: .top, name: "Navy blazer", hue: 220, isNeutral: false)
        #expect(white != nil && navy != nil)
        #expect(white != navy)
    }

    @Test func skirtAndTrousersProduceData() {
        let skirt = DemoGarmentSilhouette.pngData(
            slot: .bottom, name: "Midi skirt", hue: 15, isNeutral: false)
        let pants = DemoGarmentSilhouette.pngData(
            slot: .bottom, name: "Black trousers", hue: nil, isNeutral: true)
        #expect(skirt != nil && pants != nil)
    }
}
