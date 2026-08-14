import Foundation
import ClosetCore

/// A4（HANDOFF §6.4 / DESIGN 冷启动「可选胶囊模板引导补拍」）。
///
/// `ActivationProgress.Milestone.missingSlots` 早就算出了「还缺哪几格」，
/// 冷启动横幅也把 `milestone.nextStep` 当**一句灰字**印了出来——但那句话
/// 没有任何**可点**的下一步：用户读到「还缺一条下装」，却没有一颗按钮把他带过去。
///
/// 这里把缺口变成 CTA 的**纯拷贝 + 纯决策**，脱离 ViewInspector 可测：
/// - 点名缺口里最靠前那格（`missingSlots` 已在服务层按 `rawValue` 定序，UI 不再自作主张排序）；
/// - 开的是**通用**入库面（不预选、不举相机、不自动挑衣）——所以不用 shoot/camera 这类
///   与行为不符的词（对齐 D98：文案必须描述按钮**实际**做的事）；
/// - **永远可跳过**（`skipTitle`）：copilot 用户掌舵，缺口是提示不是关卡（D19/D98）。
///
/// 身体红线：文案评价**衣服 / 槽位**，绝不评价身体——不出现身形 / 显瘦 / 「像你」这类词。
public enum CapsuleGapCTA {

    /// 有缺口才提供补件 CTA。空集 = 这个场合已能拼出一套，别再打扰。
    public static func shouldOffer(missingSlots: [GarmentSlot]) -> Bool {
        !missingSlots.isEmpty
    }

    /// 优先补的那一格。取序列第一个——`ActivationProgress.milestone` 已按
    /// `rawValue` 定序，此处不重排（避免 UI 与 VoiceOver 各排一套）。
    public static func primarySlot(missingSlots: [GarmentSlot]) -> GarmentSlot? {
        missingSlots.first
    }

    /// 按钮标题：**点名槽位**告诉用户下一件补什么。空集 → nil（不显示按钮）。
    /// 只说「加一件 X」这个动作，不承诺效果——效果由入库后里程碑即时兑现（DESIGN §475）。
    public static func buttonTitle(missingSlots: [GarmentSlot]) -> String? {
        guard let slot = primarySlot(missingSlots: missingSlots) else { return nil }
        return "Add \(nounPhrase(for: slot))"
    }

    /// VoiceOver 标签：列**全部**缺口，免得只念一格让用户以为补完这件就齐了。
    /// 空集 → nil。
    public static func accessibilityLabel(missingSlots: [GarmentSlot]) -> String? {
        guard !missingSlots.isEmpty else { return nil }
        let names = missingSlots.map { nounPhrase(for: $0) }
        return "Add \(ActivationProgress.listJoin(names)) to complete a look"
    }

    /// 永远可跳过——copilot 不替用户拿主意。措辞刻意中性：不得暗示「必须 / 需要」。
    public static let skipTitle = "Not now"

    /// 冠词 / 单复数：shoes 复数、outerwear 不可数都不加 a/an；其余加 a/an。
    static func nounPhrase(for slot: GarmentSlot) -> String {
        switch slot {
        case .top: return "a top"
        case .bottom: return "a bottom"
        case .dress: return "a dress"
        case .outerwear: return "outerwear"
        case .shoes: return "shoes"
        case .accessory: return "an accessory"
        }
    }
}
