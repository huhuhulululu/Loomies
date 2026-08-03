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

    public init(personID: UUID) { self.personID = personID }

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
        }
        recompute()
    }

    public func save(in context: ModelContext) {
        let p = ensureProfile(in: context)
        applyForm(to: p)
        BodyProfileService.refreshSource(on: p)
        ModelSave.save(context, label: "bodyProfile")
        recompute()
        message = saveMessage
        AppLog.info("body save complete=\(isComplete) conf=\(confidence.rawValue)", .data)
    }

    /// 快选体型并立即落库。
    public func selectPopularShape(_ shape: PopularShape, in context: ModelContext) {
        selectedPopular = shape
        let p = ensureProfile(in: context)
        p.popularShapeOverrideRaw = shape.rawValue
        BodyProfileService.refreshSource(on: p)
        ModelSave.save(context, label: "bodyShapePick")
        recompute()
        message = "Saved \(displayTitle(shape)). Refine with measurements for better fit tips."
        AppLog.info("body visualPick=\(shape.rawValue)", .data)
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

    private func applyForm(to p: PersonBodyProfile) {
        p.bustInches = bustInches
        p.waistInches = waistInches
        p.hipInches = hipInches
        p.highHipInches = highHipInches
        p.highHipInferred = highHipInferred && highHipInches != nil
        p.popularShapeOverrideRaw = selectedPopular?.rawValue
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
