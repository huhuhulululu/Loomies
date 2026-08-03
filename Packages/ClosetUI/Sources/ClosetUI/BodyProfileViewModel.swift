import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// 身体四围录入 + FFIT 展示 + 真人参考体型预览（R13 门）。
@MainActor
@Observable
public final class BodyProfileViewModel {
    public let personID: UUID
    public var bust: String = ""
    public var waist: String = ""
    public var hip: String = ""
    public var highHip: String = ""
    public private(set) var shapeLabel: String?
    public private(set) var isComplete: Bool = false
    public private(set) var message: String = ""
    public private(set) var profile: PersonBodyProfile?
    /// 表单当前四围（未存也可预览）；不完整为 nil。
    public private(set) var liveMeasurements: BodyMeasurements?
    /// 大众体型（驱动真人 croquis 底图）。
    public private(set) var popularShape: PopularShape = .rectangle

    public init(personID: UUID) { self.personID = personID }

    public func load(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<PersonBodyProfile>())) ?? []
        if let p = all.first(where: { $0.personID == personID }) {
            profile = p
            bust = p.bustInches.map { String($0) } ?? ""
            waist = p.waistInches.map { String($0) } ?? ""
            hip = p.hipInches.map { String($0) } ?? ""
            highHip = p.highHipInches.map { String($0) } ?? ""
        }
        recompute()
    }

    public func save(in context: ModelContext) {
        let p = profile ?? {
            let np = PersonBodyProfile(personID: personID)
            context.insert(np)
            return np
        }()
        profile = p
        p.bustInches = Double(bust)
        p.waistInches = Double(waist)
        p.hipInches = Double(hip)
        p.highHipInches = Double(highHip)
        ModelSave.save(context, label: "bodyProfile")
        recompute()
        message = isComplete ? "Saved. Body shape ready." : "Saved. Enter all four measures to unlock fit."
        AppLog.info("body profile complete=\(isComplete)", .data)
    }

    /// 表单字段变化时刷新 FFIT + 体型预览（无动画，即时切换底图）。
    public func refreshPreview() {
        recompute()
    }

    private func recompute() {
        if let b = Double(bust), let w = Double(waist), let h = Double(hip), let hh = Double(highHip),
           b > 0, w > 0, h > 0, hh > 0 {
            let m = BodyMeasurements(bust: b, waist: w, hip: h, highHip: hh)
            liveMeasurements = m
            isComplete = true
            let shape = FFITClassifier.classify(m)
            popularShape = shape.popularCategory
            shapeLabel = "\(shape.rawValue) → \(shape.popularCategory.rawValue)"
        } else if let p = profile, BodyProfileService.isComplete(p),
                  let m = BodyProfileService.measurements(from: p) {
            liveMeasurements = m
            isComplete = true
            let shape = FFITClassifier.classify(m)
            popularShape = shape.popularCategory
            shapeLabel = "\(shape.rawValue) → \(shape.popularCategory.rawValue)"
        } else {
            liveMeasurements = nil
            isComplete = false
            shapeLabel = nil
            popularShape = .rectangle
        }
    }
}
