import Foundation

/// 身体围度（英寸）。FFIT 判定只需 bust / waist / hip / highHip 四项。
/// 单位固定英寸（en-US 主市场英制优先，DESIGN §10.5）；公制在 UI 层换算，核心逻辑不掺单位。
public struct BodyMeasurements: Equatable, Sendable {
    public let bust: Double
    public let waist: Double
    public let hip: Double
    public let highHip: Double

    public init(bust: Double, waist: Double, hip: Double, highHip: Double) {
        self.bust = bust
        self.waist = waist
        self.hip = hip
        self.highHip = highHip
    }
}
