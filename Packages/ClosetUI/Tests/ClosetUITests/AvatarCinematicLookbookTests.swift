import Testing
import CoreGraphics
import ClosetCore
@testable import ClosetUI

@Suite("AvatarCinematicLookbook")
struct AvatarCinematicLookbookTests {
    @Test func frontHoldsShowGarments() {
        let start = AvatarCinematicLookbook.pose(at: 0)
        let early = AvatarCinematicLookbook.pose(at: 0.2)
        let end = AvatarCinematicLookbook.pose(at: 1)
        let late = AvatarCinematicLookbook.pose(at: 0.8)
        #expect(start.yaw == .deg0 && start.showGarments)
        #expect(early.yaw == .deg0 && early.showGarments)
        #expect(end.yaw == .deg0 && end.showGarments)
        #expect(late.yaw == .deg0 && late.showGarments)
    }

    @Test func midOrbitHidesGarmentsAndLeavesFront() {
        let mid = AvatarCinematicLookbook.pose(at: 0.5)
        #expect(mid.showGarments == false)
        #expect(mid.yaw != .deg0)
    }

    @Test func orbitVisitsBack() {
        var yaws = Set<BodyAvatarYaw>()
        for i in 0...20 {
            let t = 0.24 + (0.52 * Double(i) / 20.0)
            yaws.insert(AvatarCinematicLookbook.pose(at: t).yaw)
        }
        #expect(yaws.contains(.deg180))
        #expect(yaws.contains(.deg90))
    }
}

@Suite("AvatarContactShadowLayout")
struct AvatarContactShadowLayoutTests {
    @Test func tallerMorphDropsShadowFurther() {
        let short = BodyMorphParams(chest: 1, waist: 1, hip: 1, shoulder: 1, height: 0.94)
        let tall = BodyMorphParams(chest: 1, waist: 1, hip: 1, shoulder: 1, height: 1.08)
        let yShort = AvatarContactShadowLayout.offsetY(canvasHeight: 300, morph: short)
        let yTall = AvatarContactShadowLayout.offsetY(canvasHeight: 300, morph: tall)
        #expect(yTall > yShort)
    }

    @Test func widerMorphWidensShadow() {
        let narrow = BodyMorphParams(chest: 0.92, waist: 1, hip: 0.95, shoulder: 0.95, height: 1)
        let wide = BodyMorphParams(chest: 1.08, waist: 1, hip: 1.1, shoulder: 1.05, height: 1)
        let a = AvatarContactShadowLayout.size(canvas: CGSize(width: 200, height: 300), morph: narrow)
        let b = AvatarContactShadowLayout.size(canvas: CGSize(width: 200, height: 300), morph: wide)
        #expect(b.width > a.width)
    }
}
