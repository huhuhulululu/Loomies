import Testing
@testable import ClosetCore

struct BodyAvatarLayoutTests {

    @Test func anchorsCoverAllSlotsWithValidRects() {
        for slot in BodyAvatarSlot.allCases {
            let f = BodyAvatarAnchors.frame(for: slot)
            #expect(f.x >= 0 && f.y >= 0)
            #expect(f.width > 0 && f.height > 0)
            #expect(f.x + f.width <= 1.001)
            #expect(f.y + f.height <= 1.001)
        }
    }

    @Test func zOrderShoesUnderOuterwear() {
        #expect(BodyAvatarAnchors.zIndex(for: .shoes) < BodyAvatarAnchors.zIndex(for: .bottom))
        #expect(BodyAvatarAnchors.zIndex(for: .bottom) < BodyAvatarAnchors.zIndex(for: .top))
        #expect(BodyAvatarAnchors.zIndex(for: .top) < BodyAvatarAnchors.zIndex(for: .outerwear))
    }

    @Test func scaleClampsExtremeMeasurements() {
        let tiny = BodyMeasurements(bust: 20, waist: 18, hip: 22, highHip: 20)
        let s = BodyAvatarScaler.scale(from: tiny)
        #expect(s.widthScale >= 0.88)
        let huge = BodyMeasurements(bust: 60, waist: 55, hip: 65, highHip: 60)
        let h = BodyAvatarScaler.scale(from: huge)
        #expect(h.widthScale <= 1.14)
    }

    @Test func scaleNeutralNearOne() {
        let m = BodyMeasurements(bust: 36, waist: 28, hip: 38, highHip: 34)
        let s = BodyAvatarScaler.scale(from: m)
        #expect(abs(s.widthScale - 1.0) < 0.05)
    }

    @Test func dressDropsTopAndBottom() {
        let layers = BodyAvatarComposer.layers(slots: [
            .dress: "dressA", .top: "topA", .bottom: "botA", .shoes: "shoeA"
        ])
        let slots = Set(layers.map(\.slot))
        #expect(slots.contains(.dress))
        #expect(!slots.contains(.top))
        #expect(!slots.contains(.bottom))
        #expect(slots.contains(.shoes))
        #expect(layers.map(\.zIndex) == layers.map(\.zIndex).sorted())
    }

    @Test func assetNamesForAllPopularShapes() {
        for shape in PopularShape.allCases {
            let n = BodyAvatarAsset.croquisName(for: shape)
            #expect(n.hasPrefix("croquis_"))
        }
        #expect(BodyAvatarAsset.allNames.count == PopularShape.allCases.count)
    }

    @Test func resolveShapeDefaultsRectangleWhenNil() {
        #expect(BodyAvatarComposer.resolveShape(from: nil) == .rectangle)
    }
}
