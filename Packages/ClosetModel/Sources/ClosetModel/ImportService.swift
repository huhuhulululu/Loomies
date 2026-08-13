import Foundation
import SwiftData
import ClosetCore

/// 数据导入（D122）。
///
/// 隐私政策里写着「Export my data … so you can take everything with you」——
/// 可搬出去之后**没有任何地方能搬回来**：换手机、误删、从别的 App 迁过来，
/// 用户都得把几小时的录入重做一遍。一条只出不进的通道算不上数据可携带性。
///
/// 三条取舍都关系到「会不会把用户已有的东西弄坏」：
/// 1. **只增不改**——永远建新衣柜，绝不覆盖或合并。合并要用户逐条裁决冲突，
///    那是一整个交互；在没有它之前，「不碰你已有的东西」是唯一安全的默认。
/// 2. **如实报告**——导入了几件、照片没跟过来，都要说出口。
/// 3. **不可信输入**——文件可能来自任何人：坏 JSON、更高的 schema 版本、
///    指向本机不存在的图片路径，都不能让 App 崩或写脏库。
public enum ImportService {

    public enum ImportError: Error, Equatable {
        /// 解不出快照（不是本 App 的导出，或文件坏了）。
        case unreadable
        /// 来自更新版本的 App——**不猜**，让用户先升级。
        case newerSchema(found: Int, supported: Int)
        /// 落库失败（已整体回滚）。
        case saveFailed
    }

    /// 本 App 能读的最高快照版本。
    public static let supportedSchemaVersion = 1

    public struct Receipt: Equatable, Sendable {
        public let wardrobesAdded: Int
        public let itemsAdded: Int
        public let outfitsAdded: Int
        /// D134：此前**穿着历史、计划、位置、主人、身体档案一条都没导**，
        /// 而收据只提「照片没跟过来」——用户以为搬完了，实际丢了一年的记录。
        public let wearRecordsAdded: Int
        public let plansAdded: Int
        public let locationsAdded: Int
        /// 指向本机不存在的图片、被清掉的件数。
        public let imagePathsCleared: Int
        /// D177：身体围度导入了几份 / 因未同意跳过了几份。
        /// 两个数都要有——只报导入的那个数，跳过时收据就成了沉默。
        public var bodyProfilesAdded: Int = 0
        public var bodyProfilesSkippedForConsent: Int = 0
        /// D186：转移历史。此前整张表零读取——导得出、导不回。
        public var transfersAdded: Int = 0
        /// D186：主人。此前落了库但收据一个字不提，空快照时还会说「Nothing to import」。
        public var personsAdded: Int = 0

        /// 用户读得懂的收据。**必须点名照片没跟过来**——
        /// JSON 里只有路径没有像素，不说清用户会以为图也回来了。
        public var summary: String {
            // D186：判空要数**全部**落库的表。此前只看衣柜与件数，
            // 而人、身体档案、穿着历史、计划在 save 之前就已无条件 insert——
            // 东西进了库，收据却说什么都没导。
            let landed = wardrobesAdded + itemsAdded + outfitsAdded + wearRecordsAdded
                + plansAdded + locationsAdded + bodyProfilesAdded + transfersAdded
                + personsAdded
            guard landed > 0 else {
                return "Nothing to import — that file had no closets or pieces."
            }
            guard wardrobesAdded > 0 || itemsAdded > 0 else {
                var others: [String] = []
                if personsAdded > 0 { others.append("\(personsAdded) profile(s)") }
                if wearRecordsAdded > 0 { others.append("\(wearRecordsAdded) wear records") }
                if plansAdded > 0 { others.append("\(plansAdded) plans") }
                if transfersAdded > 0 { others.append("\(transfersAdded) move records") }
                if bodyProfilesAdded > 0 { others.append("body measurements") }
                let list = others.isEmpty ? "some records" : others.joined(separator: ", ")
                return "That file had no closets or pieces — imported \(list) only."
            }
            let pieces = itemsAdded == 1 ? "1 piece" : "\(itemsAdded) pieces"
            let closets = wardrobesAdded == 1 ? "1 closet" : "\(wardrobesAdded) closets"
            var extras: [String] = []
            if outfitsAdded > 0 { extras.append("\(outfitsAdded) looks") }
            if wearRecordsAdded > 0 { extras.append("\(wearRecordsAdded) wear records") }
            if plansAdded > 0 { extras.append("\(plansAdded) plans") }
            if locationsAdded > 0 { extras.append("\(locationsAdded) storage spots") }
            if transfersAdded > 0 { extras.append("\(transfersAdded) move records") }
            if bodyProfilesAdded > 0 { extras.append("body measurements") }
            let tail = extras.isEmpty ? "" : " Also brought over: \(extras.joined(separator: ", "))."
            // 跳过的必须说出口，还要说清怎么拿回来——沉默地丢掉围度
            // 与沉默地存下围度一样不诚实。
            let skipped = bodyProfilesSkippedForConsent > 0
                ? " Body measurements were left out — turn on body measurements in Me → Body, "
                    + "then import the file again."
                : ""
            return "Imported \(pieces) into \(closets).\(tail)\(skipped) "
                + "Photos aren't part of the data file — add them again when you like."
        }
    }

    /// 导入一个导出快照。抛错时**什么都不会留下**。
    @MainActor
    @discardableResult
    public static func importSnapshot(
        _ data: Data, into context: ModelContext,
        consent: BodyDataConsent = .shared
    ) throws -> Receipt {
        let snapshot: DataLifecycleService.ExportSnapshot
        do {
            let decoder = JSONDecoder()
            // 导出侧把 nan/inf 编成字符串（历史脏数据兜底），读回来要对称
            decoder.nonConformingFloatDecodingStrategy = .convertFromString(
                positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
            snapshot = try decoder.decode(
                DataLifecycleService.ExportSnapshot.self, from: data)
        } catch {
            AppLog.error("import decode failed: \(AppLog.errRef(error))", .data)
            throw ImportError.unreadable
        }
        guard snapshot.schemaVersion <= supportedSchemaVersion else {
            AppLog.notice("import refused: schema \(snapshot.schemaVersion)", .data)
            throw ImportError.newerSchema(
                found: snapshot.schemaVersion, supported: supportedSchemaVersion)
        }

        // 记下新建的对象，失败时逐一断关系再 rollback（D112 纪律）
        var newWardrobes: [Wardrobe] = []
        var newItems: [Item] = []
        var newOutfits: [Outfit] = []
        var newLocations: [StorageLocation] = []
        var newRecords: [WearRecord] = []
        var newPlans: [CalendarPlan] = []
        var newPersons: [Person] = []
        var newProfiles: [PersonBodyProfile] = []
        var imagePathsCleared = 0
        let iso = ISO8601DateFormatter()

        // 导入的 id 一律**重新生成**：原 id 可能与本机已有对象撞车，
        // 而撞车的后果是悄悄改写用户已有的数据。
        var wardrobeMap: [String: Wardrobe] = [:]
        let existingNames = Set((try? context.fetch(FetchDescriptor<Wardrobe>()))?
            .map(\.name) ?? [])

        // D134：**主人也要带过来**——没有主人，导入的柜永远没有体型档案，
        // copilot 的个性化与合身标记对它永久关闭。
        var personMap: [String: Person] = [:]
        for dto in snapshot.persons {
            let person = Person(name: dto.name)
            person.coldBias = dto.coldBias
            person.personalColorSeasonRaw = dto.personalColorSeasonRaw
            person.primaryOccasionRaw = dto.primaryOccasionRaw
            context.insert(person)
            personMap[dto.id] = person
            newPersons.append(person)
        }

        for dto in snapshot.wardrobes {
            let w = Wardrobe(name: uniqueName(dto.name, taken: existingNames.union(
                newWardrobes.map(\.name))))
            w.locationCity = TextNormalize.blankToNil(dto.locationCity)
            if let pid = dto.ownerID, let owner = personMap[pid] { w.owner = owner }
            context.insert(w)
            wardrobeMap[dto.id] = w
            newWardrobes.append(w)
        }

        // 存放位置：先建再连父子（快照里父可能排在子后面）
        var locationMap: [String: StorageLocation] = [:]
        for dto in snapshot.locations {
            let loc = StorageLocation(name: dto.name)
            if let wid = dto.wardrobeID, let w = wardrobeMap[wid] { loc.wardrobe = w }
            context.insert(loc)
            locationMap[dto.id] = loc
            newLocations.append(loc)
        }
        for dto in snapshot.locations {
            if let pid = dto.parentID, let parent = locationMap[pid] {
                locationMap[dto.id]?.parent = parent
            }
        }

        var itemMap: [String: Item] = [:]
        for dto in snapshot.items {
            let item = Item(name: dto.name)
            item.slotRaw = dto.slotRaw
            item.statusRaw = dto.statusRaw
            item.subtype = dto.subtype
            item.occasionsRaw = dto.occasionsRaw
            item.warmthRaw = dto.warmthRaw
            item.colorHue = dto.colorHue
            item.colorIsNeutral = dto.colorIsNeutral
            item.attributesRaw = dto.attributesRaw
            item.brand = dto.brand
            item.sizeLabel = dto.sizeLabel
            item.chestFlatWidthInches = dto.chestFlatWidthInches
            item.waistFlatWidthInches = dto.waistFlatWidthInches
            item.hipFlatWidthInches = dto.hipFlatWidthInches
            item.barcode = dto.barcode
            item.careRaw = dto.careRaw
            // D138：`Item.notes` 的实体注释白纸黑字写着「落库前必过 sanitize」——
            // 而导入这条路绕过了它，偏偏导入的文件是**最不可信的输入**
            //（谁给的都可能，长度与控制字符都不受本 App 控制）。
            item.notes = ItemNotes.sanitize(dto.notes)
            // 图片路径指向的是**导出那台设备**的文件。留着会让网格显示一批
            // 永远加载不出来的空格子——照片不在 JSON 里，如实清掉并在收据里说明。
            if TextNormalize.blankToNil(dto.localImageRelativePath) != nil {
                imagePathsCleared += 1
            }
            item.localImageRelativePath = nil
            if let wid = dto.wardrobeID, let w = wardrobeMap[wid] {
                item.wardrobe = w
            } else if let first = newWardrobes.first {
                item.wardrobe = first          // 快照里没柜归属 → 落到导入的第一个柜
            } else {
                // D138：快照有件却没有任何衣柜——此前这些件被插进库却**没有归属**，
                // 任何界面都看不到它们（`Wardrobe.items` 是唯一入口），
                // 而收据还写着「导入 N 件到 0 个衣柜」。给它们建一个柜。
                let fallback = Wardrobe(name: uniqueName(
                    "Imported closet", taken: existingNames))
                context.insert(fallback)
                newWardrobes.append(fallback)
                item.wardrobe = fallback
            }
            if let lid = dto.locationID { item.location = locationMap[lid] }
            item.sizeSystemRaw = dto.sizeSystemRaw
            item.lastWashedAt = dto.lastWashedAt.flatMap { iso.date(from: $0) }
            context.insert(item)
            itemMap[dto.id] = item
            newItems.append(item)
        }

        for dto in snapshot.outfits {
            let outfit = Outfit(name: dto.name)
            if let wid = dto.wardrobeID, let w = wardrobeMap[wid] { outfit.wardrobe = w }
            outfit.items = dto.itemIDs.compactMap { itemMap[$0] }
            outfit.isFavorite = dto.isFavorite
            // D186：场合与缺件标记此前一并丢弃。`occasionRaw` 在卡片背景与
            // 「N pieces · Work」上都在用；`permanentlyMissing` 重置成 false 会让
            // 一个成员已被删的残缺 look 不带任何警示地混回收藏列表。
            outfit.occasionRaw = dto.occasionRaw
            outfit.missing = dto.missing
            outfit.permanentlyMissing = dto.permanentlyMissing
            context.insert(outfit)
            newOutfits.append(outfit)
        }

        // 身体档案（D5 本地域）：跟着主人走，**但先过同意门**。
        //
        // D177：这段此前一个字都没读 `isGranted`——同意 off 的用户导入一份
        // 带围度的文件，围度照样落库并被合身标记/体型头像消费，而 Me → Body
        // 仍只显示那张「要不要用你的围度」的同意卡。判定必须在
        // **任何 insert 之前**（BodyDataConsent 抬头那条铁律：insert 之后
        // 再回头删会留下 pending 脏行，污染下一次无关 save）。
        let bodyDTOs = snapshot.bodyProfiles ?? []
        let bodyAllowed = consent.isGranted
        if !bodyAllowed, !bodyDTOs.isEmpty {
            AppLog.notice("import skipped \(bodyDTOs.count) body profile(s): consent off", .data)
        }
        for dto in bodyAllowed ? bodyDTOs : [] {
            guard let person = personMap[dto.personID] else { continue }
            let profile = PersonBodyProfile(personID: person.id)
            profile.bustInches = dto.bustInches
            profile.waistInches = dto.waistInches
            profile.hipInches = dto.hipInches
            profile.highHipInches = dto.highHipInches
            profile.popularShapeOverrideRaw = dto.popularShapeOverrideRaw
            profile.shapeSourceRaw = dto.shapeSourceRaw
            profile.highHipInferred = dto.highHipInferred
            // D186：展示底座与精调值此前一并丢弃——头像的性别/人种被静默改回
            // 默认（女性/东亚），精调滑杆全部归 1。恢复备份不该悄悄换掉一个人的样子。
            profile.fineChest = dto.fineChest
            profile.fineWaist = dto.fineWaist
            profile.fineHip = dto.fineHip
            profile.fineHeight = dto.fineHeight
            profile.presentationSexRaw = dto.presentationSexRaw
            profile.presentationPhenotypeRaw = dto.presentationPhenotypeRaw
            context.insert(profile)
            newProfiles.append(profile)
        }

        // 穿着历史：`wornItemIDs` 是**软引用**，必须重映射到新 id，
        // 否则导进来的记录指向一批本机不存在的单品（等于没导）。
        for dto in snapshot.wearRecords {
            guard let date = iso.date(from: dto.date) else { continue }
            let record = WearRecord(date: date)
            record.wornItemIDs = dto.wornItemIDs.compactMap { itemMap[$0]?.id.uuidString }
            if let wid = dto.wardrobeSnapshotID { record.wardrobeSnapshotID = wardrobeMap[wid]?.id }
            record.fitFeedback = dto.fitFeedback
            context.insert(record)
            newRecords.append(record)
        }

        var outfitMap: [String: Outfit] = [:]
        for (i, dto) in snapshot.outfits.enumerated() where i < newOutfits.count {
            outfitMap[dto.id] = newOutfits[i]
        }
        for dto in snapshot.plans {
            guard let date = iso.date(from: dto.date) else { continue }
            let plan = CalendarPlan(date: date)
            if let oid = dto.outfitID { plan.outfit = outfitMap[oid] }
            plan.needsAttention = dto.needsAttention
            plan.dayKey = dto.dayKey ?? ""
            context.insert(plan)
            newPlans.append(plan)
        }

        // 转移历史（D186）。此前整张表零读取——导得出、导不回，而详情页
        // 真在渲染「Moved from X to Y」，换手机之后那一栏就空了。
        //
        // 三个 id 全是**软引用**，必须重映射到新 id：照抄原值等于指向一批
        // 本机不存在的行（`wornItemIDs` 同一条纪律，D134 已踩过一次）。
        // 单品映射不上就整条丢——一条不知道在说哪件衣服的移动记录没有意义；
        // 而衣柜映射不上仍保留（`TransferHistory` 对查不到的柜有
        // 「deleted closet」兜底，那正是它存在的理由）。
        var newTransfers: [TransferRecord] = []
        for dto in snapshot.transfers {
            guard let date = iso.date(from: dto.date),
                  let rawItemID = dto.itemID,
                  let item = itemMap[rawItemID]
            else { continue }
            let record = TransferRecord(
                itemID: item.id,
                from: dto.fromWardrobeID.flatMap { wardrobeMap[$0]?.id },
                to: dto.toWardrobeID.flatMap { wardrobeMap[$0]?.id },
                date: date)
            context.insert(record)
            newTransfers.append(record)
        }

        guard ModelSave.save(context, label: "importSnapshot") else {
            // 断关系再 rollback：不断的话幻影会被下一次无关 save 写进库（D112）
            for plan in newPlans { plan.outfit = nil }
            for outfit in newOutfits { outfit.wardrobe = nil; outfit.items = [] }
            for item in newItems { item.wardrobe = nil; item.location = nil }
            for loc in newLocations { loc.wardrobe = nil; loc.parent = nil }
            for w in newWardrobes { w.owner = nil }
            _ = newRecords; _ = newProfiles; _ = newPersons; _ = newTransfers
            context.rollback()
            AppLog.error("import save failed", .data)
            throw ImportError.saveFailed
        }
        AppLog.notice(
            "import +\(newWardrobes.count) closets +\(newItems.count) items", .data)
        return Receipt(
            wardrobesAdded: newWardrobes.count,
            itemsAdded: newItems.count,
            outfitsAdded: newOutfits.count,
            wearRecordsAdded: newRecords.count,
            plansAdded: newPlans.count,
            locationsAdded: newLocations.count,
            imagePathsCleared: imagePathsCleared,
            bodyProfilesAdded: newProfiles.count,
            bodyProfilesSkippedForConsent: bodyAllowed ? 0 : bodyDTOs.count,
            transfersAdded: newTransfers.count,
            personsAdded: newPersons.count)
    }

    /// 同名不覆盖：`Home` → `Home (imported)` → `Home (imported 2)`。
    /// 用户得能一眼认出哪个是刚导进来的。
    static func uniqueName(_ raw: String, taken: Set<String>) -> String {
        let base = TextNormalize.blankToNil(raw) ?? "Imported closet"
        guard taken.contains(base) else { return base }
        let suffixed = "\(base) (imported)"
        guard taken.contains(suffixed) else { return suffixed }
        var n = 2
        while taken.contains("\(base) (imported \(n))") { n += 1 }
        return "\(base) (imported \(n))"
    }
}
