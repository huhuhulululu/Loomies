import Testing
import Foundation
import SwiftData
@testable import ClosetModel
import ClosetCore

/// D90：单品原图的 iCloud 备份策略裁决（缺口 #19）。
///
/// 两难：`Application Support` 默认进 iCloud 备份。排除 → 换机后整柜照片全丢，
/// 用户要把衣橱重拍一遍；不排除 → 照片进用户自己的 iCloud 备份。
///
/// **裁决：不排除。** 理由：我们的隐私承诺是「我们没有你的副本、不运营账号」——
/// 这条不受影响；iCloud 备份是**用户自己的**加密备份，不是把数据交给我们或第三方。
/// 而丢光整柜照片是灾难级体验。代价是必须**如实告知**：照片会进设备备份。
///
/// 身体维度不在此列——它在独立本地 store 且 D5 明令不同步（另有 schema 门守着）。
struct ImageBackupPolicyTests {
    init() { ItemImageTestRoot.install() }

    /// 决策是**可执行的事实**，不是注释里的一句话：目录不得带排除备份标记。
    @Test func itemImagesAreNotExcludedFromBackup() throws {
        let root = try #require(ItemImageStore.rootDirectory)
        let values = try root.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup != true,
                "照片被排除出备份 = 换机丢光整柜；改这条前先读 D90")
        #expect(ItemImageStore.excludesFromBackup == false)
    }

    /// 承诺与事实一致：披露文案说了「会进设备备份」，代码就不能偷偷排除；
    /// 反之若将来改为排除，这条对账会红，逼文案同步。
    @Test func disclosureMatchesTheActualPolicy() {
        let text = ItemImageStore.backupDisclosure.lowercased()
        #expect(text.contains("backup"))
        if ItemImageStore.excludesFromBackup {
            #expect(text.contains("not included") || text.contains("excluded"))
        } else {
            #expect(text.contains("included"))
            // 不得暗示我们能看到这些备份
            #expect(!text.contains("our server"))
            #expect(!text.contains("we can"))
        }
    }
}

/// D101（审计 confirmed）：**正确的文案存在却没人用，而 UI 手写了一句假的**。
/// D90 写好了 `ItemImageStore.backupDisclosure`（照片进设备备份、我们收不到副本），
/// 它零 UI 调用点；与此同时 Me → Data 手写着「卸载不会抹掉 iCloud 同步的数据」——
/// 而两个 store 的 `cloudKitDatabase` 都是 `.none`，**什么都没同步**。
struct BackupDisclosureIsTheOneTruthTests {

    static func productionSources() -> [URL] {
        let packages = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let appShell = packages.deletingLastPathComponent()
            .appendingPathComponent("app-shell", isDirectory: true)
        var files: [URL] = []
        let fm = FileManager.default
        for root in [packages, appShell] {
            let en = fm.enumerator(at: root, includingPropertiesForKeys: nil)
            while let url = en?.nextObject() as? URL {
                guard url.pathExtension == "swift",
                      url.path.contains("/Sources/") || url.path.contains("/app-shell/"),
                      !url.path.contains("/.build/") else { continue }
                files.append(url)
            }
        }
        return files
    }

    /// 同步没开就不许出现「已同步」的话术。
    @Test func noShippedCopyClaimsCloudSyncWhileItIsOff() throws {
        // 前提：两个域都没开 CloudKit
        #expect(String(describing: LoomiesStore.mainConfiguration(inMemory: true).cloudKitDatabase)
            == String(describing: ModelConfiguration.CloudKitDatabase.none))
        var violations: [String] = []
        for url in Self.productionSources() {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (n, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let s = line.trimmingCharacters(in: .whitespaces)
                guard !s.hasPrefix("//"), !s.hasPrefix("///") else { continue }
                // 只看字符串字面量里的话术
                guard s.contains("\"") else { continue }
                if s.localizedCaseInsensitiveContains("icloud-synced")
                    || s.localizedCaseInsensitiveContains("synced to icloud") {
                    violations.append("\(url.lastPathComponent):\(n + 1) ~ \(s)")
                }
            }
        }
        #expect(violations.isEmpty, Comment(rawValue: "\(violations)"))
    }

    /// D90 那句正确的披露必须真的被 UI 用上（不是躺在常量里）。
    @Test func theCorrectDisclosureHasAUICallSite() throws {
        var used = false
        for url in Self.productionSources()
        where url.lastPathComponent != "ItemImageStore.swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if text.contains("backupDisclosure") { used = true; break }
        }
        #expect(used, "正确的备份披露零 UI 调用点，而 UI 手写了一句假的")
    }
}
