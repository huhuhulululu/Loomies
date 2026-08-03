import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// 身体四围录入 + FFIT 展示（R13 门）。
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

    private func recompute() {
        guard let p = profile else {
            isComplete = false; shapeLabel = nil; return
        }
        isComplete = BodyProfileService.isComplete(p)
        if let shape = BodyProfileService.bodyShape(from: p) {
            shapeLabel = "\(shape.rawValue) → \(shape.popularCategory.rawValue)"
        } else {
            shapeLabel = nil
        }
    }
}
