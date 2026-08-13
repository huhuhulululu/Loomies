import Testing
import Foundation
@testable import ClosetUI

/// D160（自审 D155）：**「旧图顶着」顶错了身体。**
///
/// D155 为了滑杆不闪白，加了「新图算好之前先显示上一张」。但 `@State` 的存活
/// 取决于**视图身份**，而 `BodyMorphImageView` 没有 `.id(assetName)`——
/// SwiftUI 换个 `assetName` 仍复用同一个实例，于是上一张会**跨资产**顶下去。
///
/// 后果：用户在 Me → Body 换肤色/性别时，先看到**上一个身体**约 28ms 才换过来。
/// 滑杆场景顶的是「同一个身体、略微不同的体型」——那正是想要的平滑；
/// 换身体时顶的却是**另一个人**。两件事被同一个 `@State` 混在一起了。
///
/// 而这个 App 的整套裸体底图规范（NudeBodyBaseSpec）就是围着「呈现要准确」写的，
/// 闪一下别人的身体，比闪一下空白糟得多。
struct HeldFrameIdentityTests {

    /// 同一个身体 → 可以顶（滑杆平滑，D155 的本意）。
    @Test func theSameBodyMayHoldItsPreviousFrame() {
        #expect(BodyMorphImageView.mayHoldPreviousFrame(
            shownAsset: "nude-female-eastAsian-front",
            currentAsset: "nude-female-eastAsian-front"))
    }

    /// 换了身体 → **不许顶**，宁可空一帧。
    @Test func aDifferentBodyMustNotHold() {
        #expect(!BodyMorphImageView.mayHoldPreviousFrame(
            shownAsset: "nude-female-eastAsian-front",
            currentAsset: "nude-male-eastAsian-front"),
                "换了性别还顶着上一个身体")
        #expect(!BodyMorphImageView.mayHoldPreviousFrame(
            shownAsset: "nude-female-eastAsian-front",
            currentAsset: "nude-female-black-front"),
                "换了肤色还顶着上一个身体")
        #expect(!BodyMorphImageView.mayHoldPreviousFrame(
            shownAsset: "nude-female-eastAsian-front",
            currentAsset: "nude-female-eastAsian-side"),
                "换了朝向还顶着上一帧")
    }

    /// 还没有旧图 → 没得顶。
    @Test func nothingHeldYet() {
        #expect(!BodyMorphImageView.mayHoldPreviousFrame(
            shownAsset: nil, currentAsset: "nude-female-eastAsian-front"))
    }

    /// 接线门：视图必须记住那张图**属于哪个资产**，
    /// 否则这条规则写了也没人执行。
    @Test func theViewTracksWhichBodyItIsHolding() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/ClosetUI/BodyMorphRaster.swift"),
            encoding: .utf8)
        #expect(text.contains("shownAsset"),
                "旧图没有记名 —— 换身体时会顶着别人的")
        #expect(text.contains("mayHoldPreviousFrame"),
                "判据没有被视图用上")
    }
}
