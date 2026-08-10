import Foundation
import Testing
import ClosetCore
@testable import ClosetUI

@Suite("Photo orbit side fade")
struct PhotoOrbitSideFadeTests {
    @Test func dragMaps36pxToOneCatalogStep() {
        let d = BodyAvatarView.photoOrbitYawDegrees(originDegrees: 0, translationWidth: 36)
        #expect(abs(d - (-45)) < 0.001)
        let left = BodyAvatarView.photoOrbitYawDegrees(originDegrees: 0, translationWidth: -36)
        #expect(abs(left - 45) < 0.001)
    }

    @Test func midDragDegreesAreContinuousNotStepped() {
        // Old path: Int((tx/36).rounded()) → only 0° or ±45°; mid 18px must be intermediate.
        let half = BodyAvatarView.photoOrbitYawDegrees(originDegrees: 0, translationWidth: 18)
        #expect(abs(half - (-22.5)) < 0.001)
        let quarter = BodyAvatarView.photoOrbitYawDegrees(originDegrees: 0, translationWidth: 9)
        #expect(abs(quarter - (-11.25)) < 0.001)
        #expect(abs(quarter) < abs(half))
    }

    @Test func garmentOpacityFadesSmoothlyBetweenFrontAnd45() {
        let front = MannequinGarmentVisibility.opacity(yawDegrees: 0)
        let midDeg = BodyAvatarView.photoOrbitYawDegrees(originDegrees: 0, translationWidth: 18)
        let mid = MannequinGarmentVisibility.opacity(yawDegrees: midDeg)
        let at45 = MannequinGarmentVisibility.opacity(yawDegrees: 45)
        #expect(front == 1)
        #expect(mid < front)
        #expect(mid > at45)
        // Another mid point further toward profile is strictly lower (continuous, not plateau).
        let furtherDeg = BodyAvatarView.photoOrbitYawDegrees(originDegrees: 0, translationWidth: 28)
        let further = MannequinGarmentVisibility.opacity(yawDegrees: furtherDeg)
        #expect(further < mid)
    }

    @Test func compactOrbitHintOmitsLayersCopyWhenUndressed() {
        let frontDressed = BodyAvatarView.compactOrbitHint(
            hasLayers: true, garmentYawOpacity: 1, yawLabel: "Front")
        let frontEmpty = BodyAvatarView.compactOrbitHint(
            hasLayers: false, garmentYawOpacity: 1, yawLabel: "Front")
        let sideDressed = BodyAvatarView.compactOrbitHint(
            hasLayers: true, garmentYawOpacity: 0.2, yawLabel: "¾ R")
        let sideEmpty = BodyAvatarView.compactOrbitHint(
            hasLayers: false, garmentYawOpacity: 0.2, yawLabel: "¾ R")

        #expect(frontDressed == "Drag to turn · front shows layered preview")
        #expect(frontEmpty == "Drag to turn")
        #expect(!frontEmpty.localizedCaseInsensitiveContains("layer"))
        #expect(sideDressed == "¾ R · layered preview on front only")
        #expect(sideEmpty == "¾ R")
        #expect(!sideEmpty.localizedCaseInsensitiveContains("layer"))
        #expect(frontDressed.localizedCaseInsensitiveContains("preview"))
        #expect(!frontDressed.localizedCaseInsensitiveContains("try-on"))
    }

    /// Soft-hold (missing dedicated yaw frame) must not claim a real multi-angle photo.
    @Test func softHoldOrbitCopyIsHonest() {
        let sideHoldDressed = BodyAvatarView.compactOrbitHint(
            hasLayers: true, garmentYawOpacity: 0.2, yawLabel: "¾ R", isSoftHold: true)
        let sideHoldEmpty = BodyAvatarView.compactOrbitHint(
            hasLayers: false, garmentYawOpacity: 0.2, yawLabel: "Right", isSoftHold: true)
        let frontHoldDressed = BodyAvatarView.compactOrbitHint(
            hasLayers: true, garmentYawOpacity: 1, yawLabel: "Front", isSoftHold: true)

        #expect(sideHoldDressed.contains("front hold"))
        #expect(sideHoldDressed.localizedCaseInsensitiveContains("front only")
            || sideHoldDressed.localizedCaseInsensitiveContains("clothes on front"))
        #expect(!sideHoldDressed.contains("360"))
        #expect(sideHoldEmpty == "Right · front hold")
        #expect(frontHoldDressed.contains("front hold"))
        #expect(frontHoldDressed.localizedCaseInsensitiveContains("layered"))
        #expect(!frontHoldDressed.localizedCaseInsensitiveContains("try-on"))

        let fullSide = BodyAvatarView.orbitAngleCaption(
            yawLabel: "Right", yawDegrees: 90, usesMannequin3D: false, isSoftHold: true)
        let fullFront = BodyAvatarView.orbitAngleCaption(
            yawLabel: "Front", yawDegrees: 0, usesMannequin3D: false, isSoftHold: true)
        let trueOrbit = BodyAvatarView.orbitAngleCaption(
            yawLabel: "Right", yawDegrees: 90, usesMannequin3D: false, isSoftHold: false)
        let mesh = BodyAvatarView.orbitAngleCaption(
            yawLabel: "Right", yawDegrees: 90, usesMannequin3D: true, isSoftHold: false)

        #expect(fullSide == "Right · front hold (no side photo)")
        #expect(!fullSide.contains("360"))
        #expect(fullFront == "Front")
        #expect(trueOrbit == "360° · Right")
        #expect(mesh == "360° · 90°")

        let a11yHold = BodyAvatarView.orbitAccessibilityLabel(
            sexTitle: "Female", shapeRaw: "hourglass", yawLabel: "Right", isSoftHold: true)
        let a11yTrue = BodyAvatarView.orbitAccessibilityLabel(
            sexTitle: "Female", shapeRaw: "hourglass", yawLabel: "Right", isSoftHold: false)
        #expect(a11yHold.contains("front hold"))
        #expect(a11yHold.contains("Right"))
        #expect(!a11yHold.hasSuffix("Right view"))
        #expect(a11yTrue == "Female body hourglass, Right view")

        // Icon-only orbit chevrons — angle step, not “look” carousel wording.
        #expect(BodyAvatarView.orbitStepAccessibilityLabel(direction: .previous)
            == "Previous angle")
        #expect(BodyAvatarView.orbitStepAccessibilityLabel(direction: .next)
            == "Next angle")
        #expect(!BodyAvatarView.orbitStepAccessibilityLabel(direction: .next)
            .localizedCaseInsensitiveContains("look"))
        #expect(!BodyAvatarView.orbitStepAccessibilityLabel(direction: .previous)
            .localizedCaseInsensitiveContains("try-on"))
    }

    /// Gap: explicit accessibilityLabel after children:.combine swallowed the
    /// combined wearSummary caption — VO heard only the yaw label.
    @Test func heroAccessibilityLabelAnnouncesYawAndFitCaption() {
        let yawOnly = BodyAvatarView.heroAccessibilityLabel(
            yawLabel: "Female body hourglass, Front view", fitCaption: nil)
        #expect(yawOnly == "Female body hourglass, Front view")

        let empty = BodyAvatarView.heroAccessibilityLabel(
            yawLabel: "Female body hourglass, Front view", fitCaption: "")
        #expect(empty == "Female body hourglass, Front view")

        let withCaption = BodyAvatarView.heroAccessibilityLabel(
            yawLabel: "Female body hourglass, Front view",
            fitCaption: "Proportion guide · balanced")
        #expect(withCaption.contains("Front view"))
        #expect(withCaption.contains("Proportion guide"))
    }

    /// Gap: call site used `!layers.isEmpty`, so path-only layers claimed layered preview
    /// while empty capsule / fitCaption correctly treated them as undressed.
    @Test func compactOrbitHintPathOnlyLayersDoNotClaimLayeredPreview() {
        let ghost = BodyAvatarLayer(
            id: "ghost-top",
            slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 2,
            localRelativePath: "ItemImages/missing-\(UUID().uuidString).png")
        #expect(ghost.hasVisual)
        #expect(!BodyAvatarView.hasRenderableVisual(ghost))

        // Same derivation as BodyAvatarView.orbitChrome compactChrome call site.
        // Closure form (not method ref) — avoids MainActor predicate conversion fatal.
        let hasLayers = [ghost].contains(where: { BodyAvatarView.hasRenderableVisual($0) })
        #expect(!hasLayers)
        #expect(![ghost].isEmpty, "regression guard: isEmpty would wrongly dress")

        let front = BodyAvatarView.compactOrbitHint(
            hasLayers: hasLayers, garmentYawOpacity: 1, yawLabel: "Front")
        let side = BodyAvatarView.compactOrbitHint(
            hasLayers: hasLayers, garmentYawOpacity: 0.2, yawLabel: "¾ R")
        #expect(front == "Drag to turn")
        #expect(side == "¾ R")
        #expect(!front.localizedCaseInsensitiveContains("layer"))
        #expect(!side.localizedCaseInsensitiveContains("layer"))
        #expect(!front.localizedCaseInsensitiveContains("preview"))
    }

    @Test func cinematicExportCopyDoesNotClaimTryOn() {
        #expect(CopilotCinematicExportCopy.label.localizedCaseInsensitiveContains("layered"))
        #expect(CopilotCinematicExportCopy.hint.localizedCaseInsensitiveContains("proportion"))
        #expect(CopilotCinematicExportCopy.hint.localizedCaseInsensitiveContains("not photo try-on"))
        #expect(!CopilotCinematicExportCopy.label.localizedCaseInsensitiveContains("try-on")
            || CopilotCinematicExportCopy.label.localizedCaseInsensitiveContains("not"))
    }

    @Test func photoDragEndSettlesContinuousYawOntoCatalogAngle() {
        let catalog = Set(BodyAvatarYaw.allCases.map { Double($0.rawValue) })

        // Mid-drag residual (−22.5°) must not remain unsprung after release.
        let residual = BodyAvatarView.photoOrbitYawDegrees(originDegrees: 0, translationWidth: 18)
        #expect(abs(residual - (-22.5)) < 0.001)
        let settled = BodyAvatarView.photoOrbitSettledDegrees(residual)
        #expect(catalog.contains(settled))
        #expect(settled == 0) // nearest catalog front

        // One full catalog step left (negative tx → +degrees) lands on 45°.
        let step = BodyAvatarView.photoOrbitYawDegrees(originDegrees: 0, translationWidth: -36)
        #expect(BodyAvatarView.photoOrbitSettledDegrees(step) == 45)

        // Partial drag toward profile settles onto ¾ L (315°), not a mid fade angle.
        let partial = BodyAvatarView.photoOrbitYawDegrees(originDegrees: 0, translationWidth: 28)
        #expect(BodyAvatarView.photoOrbitSettledDegrees(partial) == 315)
    }

    @Test func settledCatalogAngleAlignsChromeLabelWithGarmentFade() {
        // Residual mid-angle still fades garments while chrome may already show Front.
        let residual = BodyAvatarView.photoOrbitYawDegrees(originDegrees: 0, translationWidth: 12)
        let settled = BodyAvatarView.photoOrbitSettledDegrees(residual)
        #expect(settled == 0)
        #expect(BodyAvatarYaw(rawValue: Int(settled))?.shortLabel == "Front")

        let fadeResidual = MannequinGarmentVisibility.opacity(yawDegrees: residual)
        let fadeSettled = MannequinGarmentVisibility.opacity(yawDegrees: settled)
        #expect(fadeSettled == 1)
        #expect(fadeResidual < fadeSettled)
    }

    /// A11Y-2: VO adjustable action (one-finger swipe up/down) must step yaw the
    /// same way the chevrons do, and the re-announced value must match the new angle.
    @Test func voiceOverAdjustableStepsYawAndReannouncesLabel() {
        // increment = next angle (chevron-right); decrement = previous (chevron-left).
        #expect(BodyAvatarView.orbitAdjustableStep(increment: true) == 1)
        #expect(BodyAvatarView.orbitAdjustableStep(increment: false) == -1)

        var yaw = BodyAvatarYaw.deg0
        yaw = yaw.stepped(by: BodyAvatarView.orbitAdjustableStep(increment: true))
        #expect(yaw == .deg45)
        let steppedLabel = BodyAvatarView.orbitAccessibilityLabel(
            sexTitle: "Female", shapeRaw: "hourglass",
            yawLabel: yaw.shortLabel, isSoftHold: false)
        #expect(steppedLabel == "Female body hourglass, ¾ R view")

        // Decrement returns to Front; decrement wraps around the catalog.
        yaw = yaw.stepped(by: BodyAvatarView.orbitAdjustableStep(increment: false))
        #expect(yaw == .deg0)
        let frontLabel = BodyAvatarView.orbitAccessibilityLabel(
            sexTitle: "Female", shapeRaw: "hourglass",
            yawLabel: yaw.shortLabel, isSoftHold: false)
        #expect(frontLabel == "Female body hourglass, Front view")
        #expect(BodyAvatarYaw.deg0.stepped(
            by: BodyAvatarView.orbitAdjustableStep(increment: false)) == .deg315)

        // Soft-hold step must still re-announce honestly (no fake side photo).
        let holdLabel = BodyAvatarView.orbitAccessibilityLabel(
            sexTitle: "Female", shapeRaw: "hourglass",
            yawLabel: BodyAvatarYaw.deg45.shortLabel, isSoftHold: true)
        #expect(holdLabel.contains("front hold"))
        #expect(holdLabel.contains("¾ R"))
    }

    /// A11Y-3: orbit dots are 5–7pt visually but are the only discrete steppers
    /// in compactChrome — the tap target must clear the 24pt floor.
    @Test func orbitDotHitAreaClearsMinimumTapTarget() {
        #expect(BodyAvatarView.orbitDotHitArea >= 24)
        // Visual dot sizes the hit area wraps (regression guard vs. shrink).
        #expect(BodyAvatarView.orbitDotHitArea > 7)
    }

    /// A11Y: hero orbit chevrons keep the .title2 visual but must meet the
    /// 44pt HIG minimum hit target (same floor as lookPagerChevronHitArea).
    @Test func orbitChevronHitAreaMeetsHIGMinimum() {
        #expect(BodyAvatarView.orbitChevronHitArea >= 44)
        // Visual chevron is .title2 (~28pt) — hit area must grow past it.
        #expect(BodyAvatarView.orbitChevronHitArea > 28)
    }
}
