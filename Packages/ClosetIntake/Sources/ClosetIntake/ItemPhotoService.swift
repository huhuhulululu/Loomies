import Foundation
import SwiftData
import ClosetModel
import ClosetCore

/// 给**已经在柜里**的单品换/补一张照片（D185）。
///
/// 此前入库失败的三条提示都写着「re-add the photo later」，
/// 而 `item.localImageRelativePath` 的生产写入点只有入库新建、演示播种、导入三处——
/// 界面上没有任何补图入口。唯一的「re-add」是删掉重来，而删除是有损的：
/// 引用它的搭配会被标成 `permanentlyMissing`，穿着历史里这件从此显示为
/// 「no longer in this closet」。
///
/// 这条路与入库的 `confirm()` 走同一串工序（抠图 → 归一 → 落层图 + 旁挂原图），
/// 差别只在于「这件衣服已经存在」，所以每一步失败都必须**原样不动**——
/// 换图失败不该让用户连原来那张也丢了。
public enum ItemPhotoService {

    public enum Outcome: String, CaseIterable, Sendable {
        case replaced
        /// 抠不出前景：不落图（未抠的整幅当叠衣层会变成胸口贴纸，入库同一条纪律）。
        case cutoutFailed
        /// 读不出/对不齐：同样不落图（紧裁剪图会被叠衣器拉成全身）。
        case alignFailed
        /// 写盘失败。
        case diskFailed
        /// 落库失败（已回滚）。
        case saveFailed
    }

    public static func message(for outcome: Outcome) -> String {
        switch outcome {
        case .replaced:      return "Photo updated."
        case .cutoutFailed:  return "Couldn't cut out the photo — the old one is still there."
        case .alignFailed:   return "Couldn't align that photo for try-on — the old one is still there."
        case .diskFailed:    return "Couldn't save the photo — try again."
        case .saveFailed:    return "Couldn't save the photo — try again."
        }
    }

    /// 详情页入口的标题（有图/无图两种说法——不要对着一件没有图的衣服说「换」）。
    public static func entryTitle(hasPhoto: Bool) -> String {
        hasPhoto ? "Replace photo" : "Add a photo"
    }

    @MainActor
    @discardableResult
    public static func replacePhoto(
        for item: Item, imageData: Data,
        matting: any MattingService, in context: ModelContext
    ) async -> Outcome {
        let cut: Data
        do {
            cut = try await matting.removeBackground(imageData)
        } catch {
            AppLog.error("replacePhoto matting failed: \(AppLog.errRef(error))", .intake)
            return .cutoutFailed
        }
        let slot = IntakeViewModel.layerNormalizeSlot(slotRaw: item.slotRaw, name: item.name)
        guard let layer = GarmentLayerNormalizer.normalize(imageData: cut, slot: slot) else {
            AppLog.error("replacePhoto normalize failed item=\(AppLog.ref(item.id))", .intake)
            return .alignFailed
        }
        let previousPath = item.localImageRelativePath
        guard let rel = ItemImageStore.save(data: layer, for: item.id, ext: "png") else {
            AppLog.error("replacePhoto layer write failed item=\(AppLog.ref(item.id))", .intake)
            return .diskFailed
        }
        // 旧的派生缩略图必须作废——路径没变时它们会原样留着，
        // 网格里显示的还是上一张图。
        for variant in ItemImageVariant.allCases {
            ItemImageStore.delete(relativePath: ItemImageStore.derivedRelativePath(
                relativePath: rel, variant: variant))
        }
        // 旁挂原图（D111：导出承诺过「你加的那张照片」）。失败只记日志——
        // 为一份旁挂档把已经换好的图退回去，代价与收益不成比例。
        if ItemImageStore.saveSourcePhoto(imageData, layerRelativePath: rel) == nil {
            AppLog.error("replacePhoto source photo failed item=\(AppLog.ref(item.id))", .intake)
        }
        item.localImageRelativePath = rel
        item.revision += 1
        guard ModelSave.save(context, label: "replacePhoto") else {
            item.localImageRelativePath = previousPath
            context.rollback()
            AppLog.error("replacePhoto save failed item=\(AppLog.ref(item.id))", .intake)
            return .saveFailed
        }
        // 落库成功之后才删旧文件：save 失败时回滚会把路径退回去，
        // 那时旧文件必须还在，否则这件衣服会指向一个已经被删掉的东西。
        if let previousPath, previousPath != rel {
            ItemImageStore.deleteAll(relativePath: previousPath)
        }
        AppLog.notice("replacePhoto ok item=\(AppLog.ref(item.id))", .intake)
        return .replaced
    }
}
