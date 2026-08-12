import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// 身体双轨：5 类快选 + 四围向导（R13）+ 360 预览。
@MainActor
@Observable
public final class BodyProfileViewModel {
    public let personID: UUID

    // 测量：内部统一 inches；UI 可切 cm
    public var usesMetric: Bool = false
    public var bustInches: Double?
    public var waistInches: Double?
    public var hipInches: Double?
    public var highHipInches: Double?
    public var highHipInferred: Bool = false
    /// 手选大众体型
    public var selectedPopular: PopularShape?
    public var showMeasureTips: Bool = false
    /// 展示用 catalog 底座性别（女/男）
    public var bodySex: AvatarBodySex = .female
    /// 展示用表型（catalog 模特外观 / 肤色族）
    public var bodyPhenotype: AvatarBodyPhenotype = .eastAsian
    /// 精调乘数 0.90…1.10（1 = 不偏置）；与测量/预设合成连续 morph
    public var fineChest: Double = 1
    public var fineWaist: Double = 1
    public var fineHip: Double = 1
    public var fineHeight: Double = 1

    public private(set) var shapeLabel: String?
    public private(set) var isComplete: Bool = false
    public private(set) var message: String = ""
    public private(set) var profile: PersonBodyProfile?
    public private(set) var liveMeasurements: BodyMeasurements?
    public private(set) var popularShape: PopularShape = .rectangle
    public private(set) var confidence: BodyFitConfidence = .none
    public private(set) var measureProgress: Int = 0  // 0…4
    /// 预览用连续塑形参数
    public private(set) var morph: BodyMorphParams = .neutral

    /// 身体维度单独同意（DESIGN §2.2）。注入式便于测试；生产走 `.shared`。
    /// 门必须在**任何 context.insert 之前**判定——insert 之后再拒绝会留下
    /// pending insert + 关系幻影，污染下一次无关 save（保存原子性铁律）。
    private let bodyDataConsent: BodyDataConsent

    public init(personID: UUID, bodyDataConsent: BodyDataConsent = .shared) {
        self.personID = personID
        self.bodyDataConsent = bodyDataConsent
    }

    /// 是否已获授权写入身体数据（View 用它决定是否渲染录入面）。
    public var hasBodyDataConsent: Bool { bodyDataConsent.isGranted }

    /// 授予同意（说明卡的按钮走这里，保证 VM 与 View 读的是同一个 consent 实例）。
    public func grantBodyDataConsent() {
        bodyDataConsent.setGranted(true)
        message = ""
    }

    /// 门：未同意时给诚实提示并**在 insert 之前**返回 false。
    private func consentBlocks() -> Bool {
        guard !bodyDataConsent.isGranted else { return false }
        message = BodyDataConsent.requiredMessage
        AppLog.notice("body write refused: consent not granted", .data)
        return true
    }

    public var fineTune: BodyMorphParams {
        BodyMorphParams(
            chest: fineChest,
            waist: fineWaist,
            hip: fineHip,
            shoulder: 1,
            height: fineHeight)
    }

    public func resetFineTune() {
        fineChest = 1; fineWaist = 1; fineHip = 1; fineHeight = 1
        recompute()
    }

    public func resetFineTune(in context: ModelContext) {
        resetFineTune()
        saveFineTune(in: context)
    }

    // MARK: - Display helpers (in/cm)

    public func displayValue(inches: Double?) -> String {
        guard let inches else { return "—" }
        if usesMetric {
            return String(format: "%.0f", BodyProfileService.cm(fromInches: inches))
        }
        return String(format: "%.1f", inches)
    }

    public var unitLabel: String { usesMetric ? "cm" : "in" }

    public func stepBust(_ delta: Double) { bustInches = stepped(bustInches, delta, default: 36) }
    public func stepWaist(_ delta: Double) { waistInches = stepped(waistInches, delta, default: 28) }
    public func stepHip(_ delta: Double) { hipInches = stepped(hipInches, delta, default: 38) }
    public func stepHighHip(_ delta: Double) {
        highHipInches = stepped(highHipInches, delta, default: 34)
        highHipInferred = false
    }

    private func stepped(_ current: Double?, _ deltaUI: Double, default def: Double) -> Double {
        let stepIn = usesMetric ? BodyProfileService.inches(fromCm: deltaUI) : deltaUI
        let base = current ?? def
        return BodyProfileService.clampMeasureInches(base + stepIn)
    }

    // MARK: - Load / Save

    public func load(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<PersonBodyProfile>())) ?? []
        if let p = all.first(where: { $0.personID == personID }) {
            profile = p
            bustInches = p.bustInches
            waistInches = p.waistInches
            hipInches = p.hipInches
            highHipInches = p.highHipInches
            highHipInferred = p.highHipInferred
            selectedPopular = BodyProfileService.parsePopular(p.popularShapeOverrideRaw)
            bodySex = BodyProfileService.presentationSex(from: p)
            bodyPhenotype = BodyProfileService.presentationPhenotype(from: p)
            fineChest = Self.clampFine(p.fineChest)
            fineWaist = Self.clampFine(p.fineWaist)
            fineHip = Self.clampFine(p.fineHip)
            fineHeight = Self.clampFine(p.fineHeight)
        }
        recompute()
    }

    /// Customer toast when any body profile ModelSave fails.
    public static let saveFailedMessage = "Couldn't save body profile — try again"

    public func save(in context: ModelContext) {
        guard !consentBlocks() else { return }
        let wasNew = profile == nil
        let p = ensureProfile(in: context)
        let old = ProfileSnapshot(of: p)
        applyForm(to: p)
        BodyProfileService.refreshSource(on: p)
        recompute()
        guard ModelSave.save(context, label: "bodyProfile") else {
            rollbackFailedSave(old, wasNew: wasNew, of: p, in: context)
            message = Self.saveFailedMessage
            AppLog.error("body save failed", .data)
            return
        }
        message = saveMessage
        AppLog.info("body save complete=\(isComplete) conf=\(confidence.rawValue)", .data)
    }

    /// 精调即时落库（滑杆松手或 onChange 后调用）。
    public func saveFineTune(in context: ModelContext) {
        guard !consentBlocks() else { return }
        let wasNew = profile == nil
        let p = ensureProfile(in: context)
        let old = ProfileSnapshot(of: p)
        p.fineChest = Self.clampFine(fineChest)
        p.fineWaist = Self.clampFine(fineWaist)
        p.fineHip = Self.clampFine(fineHip)
        p.fineHeight = Self.clampFine(fineHeight)
        recompute()
        guard ModelSave.save(context, label: "bodyFineTune") else {
            rollbackFailedSave(old, wasNew: wasNew, of: p, in: context)
            message = Self.saveFailedMessage
            AppLog.error("body fineTune save failed", .data)
            return
        }
    }

    /// 快选体型并立即落库。
    public func selectPopularShape(_ shape: PopularShape, in context: ModelContext) {
        guard !consentBlocks() else { return }
        selectedPopular = shape
        let wasNew = profile == nil
        let p = ensureProfile(in: context)
        let old = ProfileSnapshot(of: p)
        p.popularShapeOverrideRaw = shape.rawValue
        BodyProfileService.refreshSource(on: p)
        recompute()
        guard ModelSave.save(context, label: "bodyShapePick") else {
            rollbackFailedSave(old, wasNew: wasNew, of: p, in: context)
            message = Self.saveFailedMessage
            AppLog.error("body visualPick save failed", .data)
            return
        }
        message = "Saved \(displayTitle(shape)). Refine with measurements for better fit tips."
        AppLog.info("body visualPick=\(shape.rawValue)", .data)
    }

    /// 切换 catalog 底座性别并落库。
    public func selectBodySex(_ sex: AvatarBodySex, in context: ModelContext) {
        guard !consentBlocks() else { return }
        bodySex = sex
        let wasNew = profile == nil
        let p = ensureProfile(in: context)
        let old = ProfileSnapshot(of: p)
        p.presentationSexRaw = sex.rawValue
        recompute()
        guard ModelSave.save(context, label: "bodySex") else {
            rollbackFailedSave(old, wasNew: wasNew, of: p, in: context)
            message = Self.saveFailedMessage
            AppLog.error("body sex save failed", .data)
            return
        }
        message = "Model: \(sex.displayTitle)."
        AppLog.info("body sex changed", .data)
    }

    /// 切换 catalog 表型（外观/肤色族）并落库。
    public func selectBodyPhenotype(_ phenotype: AvatarBodyPhenotype, in context: ModelContext) {
        guard !consentBlocks() else { return }
        bodyPhenotype = phenotype
        let wasNew = profile == nil
        let p = ensureProfile(in: context)
        let old = ProfileSnapshot(of: p)
        p.presentationPhenotypeRaw = phenotype.rawValue
        recompute()
        guard ModelSave.save(context, label: "bodyPhenotype") else {
            rollbackFailedSave(old, wasNew: wasNew, of: p, in: context)
            message = Self.saveFailedMessage
            AppLog.error("body phenotype save failed", .data)
            return
        }
        message = "Look: \(phenotype.displayTitle)."
        AppLog.info("body phenotype changed", .data)
    }

    /// 用腰臀推断上臀并标记 provisional。
    public func applyInferredHighHip() {
        guard let w = waistInches, let h = hipInches, w > 0, h > 0 else {
            message = "Enter waist and hip first."
            return
        }
        highHipInches = BodyProfileService.inferHighHip(waist: w, hip: h)
        highHipInferred = true
        recompute()
        message = "High hip estimated from waist & hip. Adjust if needed."
    }

    public func clearHighHipInference() {
        highHipInferred = false
        recompute()
    }

    public func refreshPreview() { recompute() }

    // MARK: - Private

    private func ensureProfile(in context: ModelContext) -> PersonBodyProfile {
        if let profile { return profile }
        let np = PersonBodyProfile(personID: personID)
        context.insert(np)
        profile = np
        return np
    }

    /// 失败还原快照（rollback() 只清脏标记不清内存值 → 先手动还原字段；ItemStatusService 同款）。
    private struct ProfileSnapshot {
        var bustInches: Double?
        var waistInches: Double?
        var hipInches: Double?
        var highHipInches: Double?
        var highHipInferred: Bool
        var popularShapeOverrideRaw: String?
        var shapeSourceRaw: String?
        var presentationSexRaw: String?
        var presentationPhenotypeRaw: String?
        var fineChest: Double
        var fineWaist: Double
        var fineHip: Double
        var fineHeight: Double

        init(of p: PersonBodyProfile) {
            bustInches = p.bustInches
            waistInches = p.waistInches
            hipInches = p.hipInches
            highHipInches = p.highHipInches
            highHipInferred = p.highHipInferred
            popularShapeOverrideRaw = p.popularShapeOverrideRaw
            shapeSourceRaw = p.shapeSourceRaw
            presentationSexRaw = p.presentationSexRaw
            presentationPhenotypeRaw = p.presentationPhenotypeRaw
            fineChest = p.fineChest
            fineWaist = p.fineWaist
            fineHip = p.fineHip
            fineHeight = p.fineHeight
        }

        func restore(to p: PersonBodyProfile) {
            p.bustInches = bustInches
            p.waistInches = waistInches
            p.hipInches = hipInches
            p.highHipInches = highHipInches
            p.highHipInferred = highHipInferred
            p.popularShapeOverrideRaw = popularShapeOverrideRaw
            p.shapeSourceRaw = shapeSourceRaw
            p.presentationSexRaw = presentationSexRaw
            p.presentationPhenotypeRaw = presentationPhenotypeRaw
            p.fineChest = fineChest
            p.fineWaist = fineWaist
            p.fineHip = fineHip
            p.fineHeight = fineHeight
        }
    }

    /// ModelSave 失败：还原字段 + rollback；新插入的 profile 丢弃引用（rollback 撤销 insert）。
    private func rollbackFailedSave(
        _ old: ProfileSnapshot, wasNew: Bool,
        of p: PersonBodyProfile, in context: ModelContext
    ) {
        if wasNew {
            profile = nil
        } else {
            old.restore(to: p)
        }
        context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
    }

    private func applyForm(to p: PersonBodyProfile) {
        p.bustInches = bustInches
        p.waistInches = waistInches
        p.hipInches = hipInches
        p.highHipInches = highHipInches
        p.highHipInferred = highHipInferred && highHipInches != nil
        p.popularShapeOverrideRaw = selectedPopular?.rawValue
        p.presentationSexRaw = bodySex.rawValue
        p.presentationPhenotypeRaw = bodyPhenotype.rawValue
        p.fineChest = Self.clampFine(fineChest)
        p.fineWaist = Self.clampFine(fineWaist)
        p.fineHip = Self.clampFine(fineHip)
        p.fineHeight = Self.clampFine(fineHeight)
    }

    private static func clampFine(_ v: Double) -> Double {
        min(1.10, max(0.90, v.isFinite ? v : 1))
    }

    private var saveMessage: String {
        switch confidence {
        case .none:
            return "Saved. Pick a body type or enter measurements."
        case .visualOnly:
            return "Saved visual body type. Add measures to unlock fit tips."
        case .provisional:
            return "Saved. Fit is provisional (high hip estimated)."
        case .measured:
            return "Saved. Full measurements ready for fit."
        case .mixed:
            return "Saved. Measurements + shape preference stored."
        }
    }

    private func recompute() {
        measureProgress = [bustInches, waistInches, hipInches, highHipInches]
            .filter { ($0 ?? 0) > 0 }.count

        // live measurements：三围齐即可推断上臀用于预览
        if let b = bustInches, let w = waistInches, let h = hipInches, b > 0, w > 0, h > 0 {
            if let hh = highHipInches, hh > 0 {
                liveMeasurements = BodyMeasurements(bust: b, waist: w, hip: h, highHip: hh)
            } else {
                let hh = BodyProfileService.inferHighHip(waist: w, hip: h)
                liveMeasurements = BodyMeasurements(bust: b, waist: w, hip: h, highHip: hh)
            }
        } else {
            liveMeasurements = nil
        }

        let synthetic = PersonBodyProfile(personID: personID)
        applyForm(to: synthetic)
        confidence = BodyProfileService.confidence(for: synthetic)

        if let b = bustInches, let w = waistInches, let h = hipInches, let hh = highHipInches,
           b > 0, w > 0, h > 0, hh > 0 {
            isComplete = true
            let shape = FFITClassifier.classify(
                BodyMeasurements(bust: b, waist: w, hip: h, highHip: hh))
            shapeLabel = "\(shape.rawValue) → \(shape.popularCategory.rawValue)"
            popularShape = selectedPopular ?? shape.popularCategory
        } else if let sel = selectedPopular {
            isComplete = false
            shapeLabel = nil
            popularShape = sel
        } else {
            isComplete = false
            shapeLabel = nil
            popularShape = .rectangle
        }

        morph = BodyMorphParams.resolve(
            measurements: liveMeasurements,
            shape: selectedPopular ?? popularShape,
            fineTune: fineTune)
    }

    public func displayTitle(_ shape: PopularShape) -> String {
        switch shape {
        case .hourglass: return "Hourglass"
        case .pear: return "Pear"
        case .apple: return "Apple"
        case .rectangle: return "Rectangle"
        case .invertedTriangle: return "Inverted triangle"
        }
    }

    public static let allPopular: [PopularShape] = PopularShape.allCases
}
