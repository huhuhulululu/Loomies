import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// 冷启动 onboarding（DESIGN §F4 冷启动 / M1 激活漏斗）：限 2–3 题。
/// 1) 称呼  2) 主衣柜城市  3) 可选四围（跳过则 FFIT 簇隐藏）。
/// 纯逻辑可 swift test；渲染另接 View。
@MainActor
@Observable
public final class OnboardingViewModel {
    public var displayName: String = ""
    public var city: String = ""
    /// 可选身体四围（英寸）。任一项非空即尝试写 profile；四围齐才激活 FFIT。
    public var bustInches: Double?
    public var waistInches: Double?
    public var hipInches: Double?
    public var highHipInches: Double?
    /// 可选快选大众体型（可无四围）。
    public var popularShapePick: PopularShape?

    public private(set) var person: Person?
    public private(set) var wardrobe: Wardrobe?
    public private(set) var bodyProfile: PersonBodyProfile?
    public private(set) var completed: Bool = false
    /// Customer flash after finish (empty on success; save/validation failure is honest).
    public private(set) var message: String = ""

    /// 身体维度同意门（默认未同意；DESIGN §2.2）。测试可注入独立 suite。
    let bodyDataConsent: BodyDataConsent

    public init(bodyDataConsent: BodyDataConsent = .shared) {
        self.bodyDataConsent = bodyDataConsent
    }

    /// Validation toast when name/city empty (Get started still gated by canFinish in UI).
    public static let needNameAndCityMessage = "Enter your name and city to continue."

    /// Customer toast when ModelSave fails (rollback; no silent complete).
    public static let saveFailedMessage = "Couldn't finish setup — try again"

    /// 名 + 城非空即可完成；身体全可选。
    public var canFinish: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 落库 Person + 主衣柜；若有任一身体字段则写 PersonBodyProfile。
    /// Save failure rolls back inserts, leaves `completed == false` (no silent success).
    @discardableResult
    public func finish(in context: ModelContext) -> Bool {
        // Idempotent: a double call (double-tap / re-entry) must not insert duplicates.
        guard !completed else { return true }
        guard canFinish else {
            message = Self.needNameAndCityMessage
            return false
        }
        // 身体维度同意门必须在**任何 insert 之前**：insert 之后再 return false 会留下
        // pending insert + 关系幻影，污染下一次无关 save（保存原子性铁律）。
        let hasMeasures = bustInches != nil || waistInches != nil
            || hipInches != nil || highHipInches != nil
        if hasMeasures, !bodyDataConsent.isGranted {
            message = BodyDataConsent.requiredMessage
            return false
        }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cityTrim = city.trimmingCharacters(in: .whitespacesAndNewlines)

        let person = Person(name: name)
        context.insert(person)
        let wardrobe = Wardrobe(name: "Main", locationCity: cityTrim)
        wardrobe.owner = person
        context.insert(wardrobe)

        var profile: PersonBodyProfile?
        let hasPick = popularShapePick != nil
        if hasMeasures || hasPick {
            let p = PersonBodyProfile(personID: person.id)
            // 脏输入即缺失：非正/非有限围度丢弃（isComplete 会误判齐）；合法值 clamp 落库。
            func sanitized(_ v: Double?) -> Double? {
                guard let v, v.isFinite, v > 0 else { return nil }
                return BodyProfileService.clampMeasureInches(v)
            }
            p.bustInches = sanitized(bustInches)
            p.waistInches = sanitized(waistInches)
            p.hipInches = sanitized(hipInches)
            p.highHipInches = sanitized(highHipInches)
            if let pick = popularShapePick {
                p.popularShapeOverrideRaw = pick.rawValue
            }
            BodyProfileService.refreshSource(on: p)
            context.insert(p)
            profile = p
        }
        guard ModelSave.save(context, label: "onboarding") else {
            // 先解开内存关系（rollback 不回写内存幻影），再 rollback 丢弃全部 pending insert
            //（delete 只删行，脏标记会滞留污染下一次无关 save，OutfitDraftService 同款）。
            wardrobe.owner = nil
            context.rollback()
            message = Self.saveFailedMessage
            AppLog.error("onboarding save failed", .app)
            return false
        }
        self.person = person
        self.wardrobe = wardrobe
        self.bodyProfile = profile
        self.completed = true
        message = ""
        return true
    }

    /// 当前 body profile 是否已激活 FFIT（R13 四围齐）。
    public var bodyShapeReady: Bool {
        guard let p = bodyProfile else { return false }
        return BodyProfileService.isComplete(p)
    }

    /// 快选或 FFIT 任一可用。
    public var hasBodyReference: Bool {
        guard let p = bodyProfile else { return false }
        return BodyProfileService.displayPopularShape(from: p) != nil
    }

    public var bodyShape: BodyShape? {
        guard let p = bodyProfile else { return nil }
        return BodyProfileService.bodyShape(from: p)
    }
}
