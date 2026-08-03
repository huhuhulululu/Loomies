import Foundation
import SwiftData
import ClosetCore

/// 诊断包（DESIGN §10.6 / §11）：本地生成 JSON，不含身体维度明文围度（只报是否录满）。
/// 供 Me → Export diagnostics / 内测排障。
public enum DiagnosticsExport {

    public struct Snapshot: Codable, Sendable, Equatable {
        public var exportedAt: String
        public var appVersion: String
        public var build: String
        public var wardrobeCount: Int
        public var itemCount: Int
        public var outfitCount: Int
        public var wearRecordCount: Int
        public var planCount: Int
        public var bodyProfileComplete: Bool?
        public var wardrobes: [WardrobeSummary]
        public var recentLogLines: [String]
        public var flags: [String: String]
    }

    public struct WardrobeSummary: Codable, Sendable, Equatable {
        public var id: String
        public var name: String
        public var city: String?
        public var itemCount: Int
        public var availableCount: Int
        public var slots: [String: Int]
    }

    public static func snapshot(
        in context: ModelContext,
        appVersion: String = "0.1.0",
        build: String = "0",
        flags: [String: String] = [:]
    ) -> Snapshot {
        AppLog.timed("diagnostics.snapshot", .diagnostics) {
            let wardrobes = (try? context.fetch(FetchDescriptor<Wardrobe>())) ?? []
            let items = (try? context.fetch(FetchDescriptor<Item>())) ?? []
            let outfits = (try? context.fetch(FetchDescriptor<Outfit>())) ?? []
            let wears = (try? context.fetch(FetchDescriptor<WearRecord>())) ?? []
            let plans = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
            let profiles = (try? context.fetch(FetchDescriptor<PersonBodyProfile>())) ?? []

            let bodyComplete: Bool? = {
                guard let p = profiles.first else { return nil }
                return BodyProfileService.isComplete(p)
            }()

            let summaries: [WardrobeSummary] = wardrobes.map { w in
                let wItems = w.items ?? []
                var slots: [String: Int] = [:]
                for i in wItems { slots[i.slotRaw, default: 0] += 1 }
                return WardrobeSummary(
                    id: w.id.uuidString,
                    name: w.name,
                    city: w.locationCity,
                    itemCount: wItems.count,
                    availableCount: wItems.filter { $0.statusRaw == "available" }.count,
                    slots: slots
                )
            }
            .sorted { $0.name < $1.name }

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            return Snapshot(
                exportedAt: iso.string(from: Date()),
                appVersion: appVersion,
                build: build,
                wardrobeCount: wardrobes.count,
                itemCount: items.count,
                outfitCount: outfits.count,
                wearRecordCount: wears.count,
                planCount: plans.count,
                bodyProfileComplete: bodyComplete,
                wardrobes: summaries,
                recentLogLines: AppLog.ring.snapshot().suffix(80).map(\.lineText),
                flags: flags
            )
        }
    }

    public static func jsonData(_ snap: Snapshot, pretty: Bool = true) throws -> Data {
        let enc = JSONEncoder()
        if pretty { enc.outputFormatting = [.prettyPrinted, .sortedKeys] }
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(snap)
    }

    public static func jsonString(in context: ModelContext,
                                  appVersion: String = "0.1.0",
                                  build: String = "0",
                                  flags: [String: String] = [:]) throws -> String {
        let snap = snapshot(in: context, appVersion: appVersion, build: build, flags: flags)
        let data = try jsonData(snap)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
