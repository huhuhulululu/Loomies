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
    /// 场合构成（D97，DESIGN §474 个性化三题之一）。nil = 跳过，不猜。
    public var primaryOccasion: String?
    /// 可选身体四围（英寸）。任一项非空即尝试写 profile；四围齐才激活 FFIT。
    // D98：四个身体维度字段在 OnboardingScreen 上**零绑定**（用户填不了），
    // 同意门那条分支从手指永远走不到，`has_body_complete` 也结构性恒为 false ——
    // 一个不可能为真的漏斗指标，偏偏长在「漏斗度量」这个缺口里。
    // DESIGN 把四围列为可跳过，Me → Body 才是真入口，故这里整组删除。
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
    /// 只卡城市：它喂天气（真下游）。姓名不在 DESIGN §474 的个性化三题里，
    /// 也不个性化任何东西——只是 Me 里的显示标签，不该当激活闸门（D98）。
    public static let needNameAndCityMessage = "Enter your city to continue."
    /// 未填姓名时的可读占位（用户随时能在 Me → Profile 改）。
    public static let unnamedPersonLabel = "You"

    /// Customer toast when ModelSave fails (rollback; no silent complete).
    public static let saveFailedMessage = "Couldn't finish setup — try again"

    /// 名 + 城非空即可完成；身体全可选。
    public var canFinish: Bool {
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        // 体型快选也是身体数据——Me → Body 里同一个动作会被拒，两处口径必须一致（D98）。
        let hasBodyInput = popularShapePick != nil
        if hasBodyInput, !bodyDataConsent.isGranted {
            message = BodyDataConsent.requiredMessage
            return false
        }
        let name = TextNormalize.blankToNil(displayName) ?? Self.unnamedPersonLabel
        let cityTrim = city.trimmingCharacters(in: .whitespacesAndNewlines)

        let person = Person(name: name)
        // 未答就是 nil——不得静默记成某个具体场合（那是系统假设冒充用户选择）
        person.primaryOccasionRaw = OccasionMix.parse(primaryOccasion)
        context.insert(person)
        let wardrobe = Wardrobe(name: "Main", locationCity: cityTrim)
        wardrobe.owner = person
        context.insert(wardrobe)

        var profile: PersonBodyProfile?
        if let pick = popularShapePick {
            let p = PersonBodyProfile(personID: person.id)
            p.popularShapeOverrideRaw = pick.rawValue
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
        // 只发**能为真**的指标：四围在 onboarding 里根本填不了，
        // `has_body_complete` 恒 false 是假指标（D98）。
        TelemetryGate.shared.track(.onboardingCompleted, payload: [
            "has_body_complete": String(popularShapePick != nil),
        ])
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
