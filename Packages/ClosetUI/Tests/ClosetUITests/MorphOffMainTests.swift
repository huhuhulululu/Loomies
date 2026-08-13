import Testing
import Foundation
@testable import ClosetUI
import ClosetCore

/// D155：**精调滑杆每动一格，主线程做一次 27.7ms 的逐像素变形。**
///
/// 滑杆是 `step: 0.01` / 范围 0.90–1.10 → 21 个离散档位，而缓存键把 morph
/// 按 `%.3f` 量化——每一档都是新键、都是 miss、都在 view body 里同步 warp。
/// 实测单次 27.7ms（macOS，真机更慢）：**每动一格掉两帧**。
///
/// 而这正是「精调体型」那个界面——MARKET §2 认定的差异化纵深，
/// 用户在那里逐格拖动正是为了看实时反馈，卡顿恰好落在最需要顺滑的地方。
///
/// 处置照 D152 的模板：**命中就直出，未命中把 warp 放到后台**，
/// 算完回主线程落地；新键到来时旧任务由 `.task(id:)` 自动取消。
/// 期间**旧图顶着**——不顶的话滑杆一动画面就闪白，比卡顿更糟。
@MainActor
struct MorphOffMainTests {

    private let asset = "nude-female-eastAsian-front"

    /// 只查不算：未命中时**不得**在调用线程上做任何变形。
    @Test func aMissDoesNotWarpOnTheCallingThread() {
        let cache = BodyMorphImageCache.shared
        cache.purge()
        let before = cache.renderAttempts
        _ = cache.cachedImage(
            named: asset,
            morph: BodyMorphParams(chest: 1.07, waist: 0.93, hip: 1.02,
                                   shoulder: 1.0, height: 1),
            width: 390)
        #expect(cache.renderAttempts == before,
                "只查缓存的路径动手算了 —— 滑杆每格仍会在主线程 warp")
    }

    /// 后台算完之后，同一个键就命中了（结果真的落进了缓存）。
    @Test func theBackgroundRenderLandsInTheCache() async {
        let cache = BodyMorphImageCache.shared
        cache.purge()
        let morph = BodyMorphParams(chest: 1.05, waist: 0.95, hip: 1.0,
                                    shoulder: 1.0, height: 1)
        await cache.renderOffMain(named: asset, morph: morph, width: 390)
        // 资产在测试 bundle 里可能不存在——那也要**负缓存**，
        // 否则每 tick 重走读盘（这条 D109 已经栽过一次）。
        let attemptsAfterFirst = cache.renderAttempts
        _ = cache.cachedImage(named: asset, morph: morph, width: 390)
        await cache.renderOffMain(named: asset, morph: morph, width: 390)
        #expect(cache.renderAttempts == attemptsAfterFirst,
                "同一个键又算了一遍 —— 缓存没兜住（含资产缺失的负缓存）")
    }

    /// 键的量化口径不变（换算法不等于换结果：同一组参数仍是同一个键）。
    @Test func theKeyStillDistinguishesEveryStep() {
        let cache = BodyMorphImageCache.shared
        cache.purge()
        let a = BodyMorphParams(chest: 1.00, waist: 1.0, hip: 1.0, shoulder: 1.0, height: 1)
        let b = BodyMorphParams(chest: 1.01, waist: 1.0, hip: 1.0, shoulder: 1.0, height: 1)
        #expect(cache.cacheKey(named: asset, morph: a, width: 390)
                != cache.cacheKey(named: asset, morph: b, width: 390),
                "相邻两档撞成同一个键 —— 滑杆动了画面不动")
    }

    /// 非法宽度（首帧布局瞬态）照旧不算不缓存，也不 trap。
    @Test func aZeroWidthIsIgnored() {
        let cache = BodyMorphImageCache.shared
        let before = cache.renderAttempts
        #expect(cache.cachedImage(
            named: asset,
            morph: BodyMorphParams(chest: 1, waist: 1, hip: 1, shoulder: 1, height: 1),
            width: 0) == nil)
        #expect(cache.renderAttempts == before)
    }

    /// 接线门：视图必须走「异步渲染 + 旧图顶着」，不得再在 body 里同步算。
    @Test func theViewRendersOffMain() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/ClosetUI/BodyMorphRaster.swift"),
            encoding: .utf8)
        // D160：原来取「结构体开头往后 1800 字」——加两行注释就把要找的符号
        // 挤出了窗口，门当场误红。窗口式判据本身就脆，改成按**结构边界**取：
        // 视图从它的声明起，到下一个类型声明为止。
        guard let start = text.range(of: "struct BodyMorphImageView") else {
            Issue.record("找不到视图"); return
        }
        let rest = text[start.lowerBound...]
        let end = rest.range(of: "final class BodyMorphImageCache")?.lowerBound
            ?? rest.endIndex
        let body = String(rest[rest.startIndex..<end])
        #expect(body.contains("renderOffMain"),
                "视图仍在 body 里同步 warp —— 滑杆每格照掉两帧")
        #expect(body.contains(".task(id:"),
                "没有按键取消在途渲染 —— 快速拖动会积压一串过期的 warp")

        // D160：**断言符号存在不等于断言行为。**
        // 第一版只查 `shownAsset` / `mayHoldPreviousFrame` 出现过——
        // 我把守卫删掉改成 `let held = shown`，符号仍在文件里，门照样绿。
        // 真正要守的是：`shown` 的每一次**读取**都经过那道守卫。
        var unguarded: [String] = []
        for line in body.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.hasPrefix("//"), !t.hasPrefix("///") else { continue }
            // 把 shownAsset 挖掉，剩下的 shown 才是我们要管的那个
            let bare = t.replacingOccurrences(of: "shownAsset", with: "")
            guard bare.contains("shown") else { continue }
            if bare.contains("@State") { continue }            // 声明
            if bare.contains("shown =") { continue }           // 写入
            if bare.contains("mayHoldPreviousFrame") { continue }  // 经守卫读取
            unguarded.append(t)
        }
        #expect(unguarded.isEmpty, Comment(rawValue:
            "这些地方绕过守卫直接读上一帧，换身体时会顶着别人的：\(unguarded)"))
    }
}
