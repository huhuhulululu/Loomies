import Testing
import Foundation
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
