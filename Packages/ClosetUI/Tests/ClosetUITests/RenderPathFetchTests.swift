import Testing
import Foundation
@testable import ClosetUI

/// D112（性能审计）：**渲染路径里不得发数据库查询**。
///
/// `ownerProfile` 曾是计算属性里的全表 `context.fetch`，而行构建器要读它
/// 4-5 次（shape / morph / sex / phenotype），于是每滚进一行就是一把主线程
/// SQLite 往返；一次 flash 提示导致的整屏重建要付 7 行 × 4 次。
/// 同模块的 `ClosetGridView` 早就是 `@Query` + 内存 `first {}`（快约两个数量级）——
/// 这条门把三处收编后的写法钉住，防止下一个人又写回 fetch。
///
/// （不是「大衣柜才慢」：`PersonBodyProfile` 每人一行，代价与衣柜规模无关，
/// 纯粹是 SwiftData 每次往返的固定开销。）
@MainActor
struct RenderPathFetchTests {

    private var sourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetUI")
    }

    /// 取身体档案一律走 `@Query`，不得在计算属性里 fetch。
    @Test func bodyProfileLookupsNeverFetchInTheRenderPath() throws {
        var violations: [String] = []
        let fm = FileManager.default
        for case let url as URL in fm.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            // ViewModel 里的 fetch 是**一次性加载**（refresh/load），不在每行的渲染路径上——
            // 那是正当用法，本门只管 View。
            guard !url.lastPathComponent.hasSuffix("ViewModel.swift") else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where line.contains("FetchDescriptor<PersonBodyProfile>") {
                violations.append("\(url.lastPathComponent):\(i + 1)")
            }
        }
        #expect(violations.isEmpty, Comment(rawValue:
            "渲染路径里查身体档案要用 @Query（内存查找），不是 fetch：\(violations)"))
    }

    /// 三个持 `let wardrobe` 的展示视图都必须真的声明了那条 `@Query`
    /// （删掉 fetch 却忘了加 @Query 会静默变成「永远没有体型」）。
    @Test func theViewsThatShowLooksDeclareTheQuery() throws {
        for file in ["FeatureViews.swift", "CompletenessViews.swift", "FittingRoomView.swift"] {
            let text = try String(
                contentsOf: sourcesDir.appendingPathComponent(file), encoding: .utf8)
            #expect(text.contains("@Query private var bodyProfiles: [PersonBodyProfile]"),
                    Comment(rawValue: "\(file) 少了身体档案的活查询"))
            #expect(text.contains("bodyProfiles.first { $0.personID == pid }"),
                    Comment(rawValue: "\(file) 没有按主人取档案"))
        }
    }
}
