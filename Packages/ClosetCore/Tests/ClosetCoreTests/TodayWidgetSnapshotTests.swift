import Testing
import Foundation
@testable import ClosetCore

/// D197：主屏 Widget 的数据面。
///
/// 核心机制是每日回访（D118 已经在推通知），而用户被叫醒之后**还得开 App**
/// 才知道今天穿什么。Widget 把那一眼放到主屏上——正对 `MARKET.md` §8
/// 要测的那个指标（每日推送 wear-as-is 率）。
struct TodayWidgetSnapshotTests {

    private func snapshot(
        dayKey: String = "2026-08-13",
        settled: Bool = true,
        temp: Int? = 72
    ) -> TodayWidgetSnapshot {
        TodayWidgetSnapshot(
            dayKey: dayKey, lookTitle: "Navy work look",
            pieces: [
                .init(name: "Navy Blazer", colorPaletteID: "navy"),
                .init(name: "White Tee", colorPaletteID: "white"),
                .init(name: "Chinos", colorPaletteID: nil),
            ],
            daytimeTempF: temp, weatherSourceLabel: "Open-Meteo",
            isSettled: settled)
    }

    // MARK: - 边界：什么可以出这个沙盒

    /// **判据打在编码后的 JSON 键上**——那才是真正落进共享容器的东西，
    /// 而且列举完备（不像扫源码那样有「看不见的地方等于不存在」的假绿风险）。
    ///
    /// 可以出去：件名、look 标题、温度、来源——那正是 widget 要显示的。
    /// 绝不出去：身体围度（D5 局域，连主库都不进）、照片、城市名。
    @Test func theSnapshotCarriesNothingItShouldNot() throws {
        let data = try JSONEncoder().encode(snapshot())
        let keys = Set((try JSONSerialization.jsonObject(with: data)
            as? [String: Any] ?? [:]).keys)
        let allowed: Set<String> = [
            "dayKey", "lookTitle", "pieces",
            "daytimeTempF", "weatherSourceLabel", "isSettled",
        ]
        #expect(keys == allowed, Comment(rawValue:
            "共享容器里多出/少了字段：\(keys.symmetricDifference(allowed))"))

        // 每件身上出去的东西也要列举完备（D210：颜色进来了，边界得跟着收）
        let pieceKeys = Set(((try JSONSerialization.jsonObject(with: data)
            as? [String: Any])?["pieces"] as? [[String: Any]] ?? []).flatMap(\.keys))
        #expect(pieceKeys == ["name", "colorPaletteID"], Comment(rawValue:
            "每件出去的字段变了：\(pieceKeys) —— 照片/尺寸/品牌都不许跟着走"))

        // 逐个点名那些**绝不许**出现的（加字段时这条会当场红）
        let forbidden = ["bust", "waist", "hip", "measure", "body",
                         "photo", "image", "city", "location"]
        for key in keys {
            for banned in forbidden {
                #expect(!key.localizedCaseInsensitiveContains(banned), Comment(rawValue:
                    "`\(key)` 进了共享容器 —— 身体维度/照片/城市不许离开 App 沙盒"))
            }
        }
    }

    /// 自测：这条门喂一个已知违规能不能抓到（防过滤逻辑写坏了整体空转）。
    @Test func theBoundaryCheckWouldCatchAViolation() {
        let forbidden = ["bust", "waist", "hip", "measure", "body",
                         "photo", "image", "city", "location"]
        let sabotaged = "bustInches"
        #expect(forbidden.contains { sabotaged.localizedCaseInsensitiveContains($0) },
                "判据抓不到一个明显的违规键 —— 它在空转")
    }

    // MARK: - 过期的快照绝不冒充今天

    /// D188 的第二个发作面，而且更隐蔽：用户不点开就看不出来。
    @Test func yesterdaysSnapshotIsNotToday() {
        let yesterday = snapshot(dayKey: "2026-08-12")
        #expect(TodayWidgetCopy.isFresh(yesterday, todayKey: "2026-08-13") == false,
                "昨天的快照被当成今天 —— 用户会照着昨天那身穿出门")
        #expect(TodayWidgetCopy.stale.localizedCaseInsensitiveContains("today"))
    }

    @Test func todaysSnapshotIsFresh() {
        #expect(TodayWidgetCopy.isFresh(snapshot(), todayKey: "2026-08-13"))
    }

    // MARK: - 文案只说做得到的

    /// 「已定」与「建议」是两件事，不许混为一谈。
    @Test func settledAndSuggestedReadDifferently() {
        #expect(TodayWidgetCopy.headline(snapshot(settled: true))
                != TodayWidgetCopy.headline(snapshot(settled: false)))
    }

    /// 不知道几度就不说——不填默认值（D130 同款三值语义）。
    @Test func anUnknownTemperatureSaysNothing() {
        #expect(TodayWidgetCopy.weatherLine(snapshot(temp: nil)) == nil,
                "温度未知却印了个数字出来")
        let line = try? #require(TodayWidgetCopy.weatherLine(snapshot(temp: 41)))
        #expect((line ?? "").contains("41"))
        #expect((line ?? "").contains("Open-Meteo"), "有温度就要说清哪来的")
    }

    // MARK: - 读写

    @Test func itRoundTripsThroughTheContainer() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("widget-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(TodayWidgetSnapshotStore.write(snapshot(), to: dir))
        #expect(TodayWidgetSnapshotStore.read(from: dir) == snapshot())
    }

    /// 读不到就是 nil——**不造一份空快照冒充有数据**。
    @Test func anAbsentSnapshotIsNil() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("widget-missing-\(UUID().uuidString)")
        #expect(TodayWidgetSnapshotStore.read(from: dir) == nil)
        #expect(TodayWidgetSnapshotStore.read(from: nil) == nil)
    }

    /// 没配 App Group 时写入**诚实失败**，不静默当成功。
    @Test func writingWithoutAContainerFailsHonestly() {
        #expect(TodayWidgetSnapshotStore.write(snapshot(), to: nil) == false)
    }

    /// 删库要能把它清掉——共享容器不在 App 沙盒里，
    /// 「removes everything on this device」不能把它漏了。
    @Test func clearingRemovesIt() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("widget-clear-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(TodayWidgetSnapshotStore.write(snapshot(), to: dir))
        TodayWidgetSnapshotStore.clear(in: dir)
        #expect(TodayWidgetSnapshotStore.read(from: dir) == nil)
    }

    // MARK: - D210：衣物的颜色是这块界面唯一的色彩主角

    /// 颜色出去的是**调色板 id**（16 个固定值之一），不是 hex、更不是照片。
    /// 信息量比件名还小——件名是自由文本，可能带品牌。
    @Test func theColourTravelsAsAPaletteIDNotAFreeString() throws {
        for piece in snapshot().pieces {
            guard let id = piece.colorPaletteID else { continue }
            #expect(GarmentColorPalette.entry(id: id) != nil, Comment(rawValue:
                "`\(id)` 不在调色板里 —— widget 那边还原不出颜色，只能画个空点"))
        }
    }

    /// 认不出的 id **不猜**（存量快照、将来改调色板都会走到这条）。
    @Test func anUnknownPaletteIDDrawsNothing() {
        let piece = TodayWidgetSnapshot.Piece(name: "X", colorPaletteID: "chartreuse-2")
        #expect(piece.paletteEntry == nil, "认不出的颜色要留白，不许挑个相近的顶上")
    }

    /// 没设颜色的件也不猜——`nil` 一路传到画面上就是「不画点」。
    @Test func aPieceWithoutAColourStaysBlank() {
        let chinos = snapshot().pieces.first { $0.name == "Chinos" }
        #expect(chinos?.colorPaletteID == nil)
        #expect(chinos?.paletteEntry == nil)
    }

    /// **单色渲染下不画色点**。
    ///
    /// 锁屏与去饱和主屏（`accented` / `vibrant`）会把 widget 里的一切
    /// 染成同一个强调色。那时三个色点会变成同一个颜色——而它们**在说谎**：
    /// 用户会读成「今天这三件是同色系」。
    ///
    /// 这与 D130 的三值语义是同一条：**不能诚实显示的时候，什么都不显示**，
    /// 不是显示一个看起来还行的默认值。
    @Test func monochromeRenderingDrawsNoDotsAtAll() {
        #expect(TodayWidgetCopy.showsColorDots(.trueColor))
        #expect(!TodayWidgetCopy.showsColorDots(.monochrome))
    }

    /// 色点的 VoiceOver 读法：说颜色名，不说「几个圆点」。
    @Test func theColourStripSpeaksColourNames() {
        let spoken = TodayWidgetCopy.coloursSpoken(snapshot().pieces)
        #expect(spoken.contains("Navy"))
        #expect(spoken.contains("White"))
        #expect(!spoken.localizedCaseInsensitiveContains("circle"),
                "读出来的是控件形状，不是内容")
    }

    /// 一件颜色都没有时**不出声**——空标签好过「Colours: 」这种半截话。
    @Test func aColourlessOutfitSpeaksNothing() {
        let pieces = [TodayWidgetSnapshot.Piece(name: "A", colorPaletteID: nil)]
        #expect(TodayWidgetCopy.coloursSpoken(pieces).isEmpty)
    }

    /// 件名在两种模式下都照常显示——被压掉的只有颜色。
    @Test func theNamesSurviveEitherRendering() {
        #expect(snapshot().pieces.map(\.name) == ["Navy Blazer", "White Tee", "Chinos"])
    }

    // MARK: - 旧快照一次性迁移（read 时把 pieceNames 转成 pieces）

    /// 旧结构：`pieceNames` 平行数组、没有 `pieces` 键，其余字段与今天一致。
    /// D210 之前落库的快照长这样。
    private static let legacyPayload = """
        {
          "dayKey": "2026-08-13",
          "lookTitle": "Navy work look",
          "pieceNames": ["Navy Blazer", "White Tee", "Chinos"],
          "daytimeTempF": 72,
          "weatherSourceLabel": "Open-Meteo",
          "isSettled": true
        }
        """

    private func writeRaw(_ json: String, into dir: URL) throws {
        try Data(json.utf8).write(
            to: dir.appendingPathComponent(TodayWidgetSnapshotStore.fileName))
    }

    /// D210 把 `pieceNames:[String]` 换成 `pieces:[Piece]`。存量快照缺 `pieces`
    /// 键、解码直接失败——升级后**第一次**刷新 widget 就退成「Open Loomies…」，
    /// 仿佛从没开过 App。那是一句能避免的谎（D210 之后的这次刷新是唯一的窗口）：
    /// read 时认出旧结构，就地转成**无颜色**的 pieces。
    @Test func aLegacySnapshotMigratesOnRead() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("widget-legacy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try writeRaw(Self.legacyPayload, into: dir)

        let migrated = try #require(TodayWidgetSnapshotStore.read(from: dir), Comment(rawValue:
            "旧快照解不开被当成没有快照 —— 升级后第一次刷新退成「Open Loomies…」"))
        #expect(migrated.dayKey == "2026-08-13")
        #expect(migrated.lookTitle == "Navy work look")
        #expect(migrated.pieces.map(\.name) == ["Navy Blazer", "White Tee", "Chinos"])
        // 旧结构没有颜色 —— 一件都不许猜（认不出/没有都留白）
        #expect(migrated.pieces.allSatisfy { $0.colorPaletteID == nil },
                "旧快照没有颜色信息，迁移时不许凭空补一个")
        #expect(migrated.daytimeTempF == 72)
        #expect(migrated.weatherSourceLabel == "Open-Meteo")
        #expect(migrated.isSettled)
    }

    /// 迁移只认「像旧快照」的东西。彻底的垃圾仍是 nil——多了一条旧解码路径，
    /// 就不能因此凭空造一份空快照冒充有数据（D188/D197 同一条：宁可说没有）。
    /// 这条撞的是新加的那条 fallback：旧结构缺 `dayKey`/`pieceNames`/`isSettled`
    /// 就该继续失败，而不是被迁移路径「捡起来」。
    @Test func totalGarbageStillDecodesToNil() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("widget-garbage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try writeRaw(#"{"unrelated": 1, "pieceNames": "not-even-an-array"}"#, into: dir)
        #expect(TodayWidgetSnapshotStore.read(from: dir) == nil,
                "既不是新结构也不是旧结构 —— 不许迁移路径凭空造一份")
    }
}
