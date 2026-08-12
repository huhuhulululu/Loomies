import Testing
import Foundation
import ImageIO
import ClosetCore
@testable import ClosetUI

/// Photoreal 资产矩阵 QA 门：此前无任何自动化检查矩阵完整性/尺寸一致性——
/// 「eastAsian 只有正面 → 转角换人」「african yaw045 尺寸异常 → 转角跳变」
/// 都是漏网实例。任何资产增删必须让本套件先行变红/同步更新。
@Suite("PhotorealInventoryQA")
struct PhotorealInventoryQATests {

    static func photorealURLs() -> [URL] {
        // 与生产读取 fallback 同构：子目录保留或被 SPM 扁平化两种布局都要能枚举
        let sub = Bundle.module.urls(
            forResourcesWithExtension: "png", subdirectory: "BodyAvatar") ?? []
        let flat = Bundle.module.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? []
        var seen = Set<String>()
        return (sub + flat).filter {
            $0.lastPathComponent.hasPrefix("photoreal_") && seen.insert($0.lastPathComponent).inserted
        }
    }

    static func pixelSize(_ url: URL) -> (w: Int, h: Int)? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (w, h)
    }

    /// 落盘的每个 photoreal 名字都必须过认证白名单（防手滑命名逃出 resolve 链）。
    @Test func everyBundledPhotorealNameIsAllowed() {
        let urls = Self.photorealURLs()
        #expect(!urls.isEmpty)
        for url in urls {
            let name = url.deletingPathExtension().lastPathComponent
            #expect(NudeBodyBaseSpec.isAllowedPhotorealFrontName(name), "\(name)")
        }
    }

    /// 尺寸一致性：全库 2:3 比例（±1%）——非常规比例会让转角时人物大小/裁切跳变。
    @Test func everyBundledPhotorealFrameIsTwoByThree() {
        for url in Self.photorealURLs() {
            guard let s = Self.pixelSize(url) else {
                Issue.record("unreadable \(url.lastPathComponent)")
                continue
            }
            let ratio = Double(s.w) / Double(s.h)
            #expect(abs(ratio - 2.0 / 3.0) < 0.01,
                    "\(url.lastPathComponent) \(s.w)x\(s.h) ratio=\(ratio)")
        }
    }

    /// 矩阵账本：sex×phenotype×yaw 128 格中，缺格必须**恰好**等于已知待补清单
    ///（eastAsian 13 张锁脸转角图，出图任务见 BODY-AVATAR-IMAGE-PROMPTS.md §10）。
    /// 资产落盘 → 从清单删除；任何新增缺格 → 本测试失败。
    @Test func matrixGapsExactlyMatchKnownPendingList() {
        let present = Set(Self.photorealURLs().map { $0.deletingPathExtension().lastPathComponent })
        var missing = Set<String>()
        for name in BodyAvatarAsset.allPhotorealFrameNames {
            // front 与 yaw000 互为别名：任一存在即算该格有资产
            let frontAlias = name.hasSuffix("_yaw000")
                ? name.replacingOccurrences(of: "_yaw000", with: "_front") : nil
            if !present.contains(name), frontAlias.map({ !present.contains($0) }) ?? true {
                missing.insert(name)
            }
        }
        let knownPending: Set<String> = [
            "photoreal_female_eastAsian_yaw045", "photoreal_female_eastAsian_yaw090",
            "photoreal_female_eastAsian_yaw135", "photoreal_female_eastAsian_yaw180",
            "photoreal_female_eastAsian_yaw225", "photoreal_female_eastAsian_yaw270",
            "photoreal_female_eastAsian_yaw315",
            "photoreal_male_eastAsian_yaw045", "photoreal_male_eastAsian_yaw090",
            "photoreal_male_eastAsian_yaw135", "photoreal_male_eastAsian_yaw225",
            "photoreal_male_eastAsian_yaw270", "photoreal_male_eastAsian_yaw315",
        ]
        let diff = "unexpected gaps: \(missing.subtracting(knownPending).sorted()); "
            + "landed (remove from pending): \(knownPending.subtracting(missing).sorted())"
        #expect(missing == knownPending, Comment(rawValue: diff))
    }

    /// Shape 正面档（+64）账本：落盘进度 = 80 - 待补数；本轮起点为 16 已有
    ///（无 shape token 的表型正面按基础体型计，不计入 80）→ 初始 pending 80。
    /// 每落盘一张 shape 正面图，本数字应减一（更新断言），防「出了图没接上」。
    @Test func shapeFrontLedger() {
        let present = Set(Self.photorealURLs().map { $0.deletingPathExtension().lastPathComponent })
        let landed = BodyAvatarAsset.allPhotorealShapeFrontNames.filter { present.contains($0) }
        #expect(landed.count == 0,
                "shape fronts landed: \(landed.count)/80 — update this ledger as assets arrive")
    }
}
