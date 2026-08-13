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
            pieceNames: ["Navy Blazer", "White Tee", "Chinos"],
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
            "dayKey", "lookTitle", "pieceNames",
            "daytimeTempF", "weatherSourceLabel", "isSettled",
        ]
        #expect(keys == allowed, Comment(rawValue:
            "共享容器里多出/少了字段：\(keys.symmetricDifference(allowed))"))

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
}
