import SwiftUI
#if canImport(CoreMotion) && os(iOS)
import CoreMotion
#endif

/// 景深视差强度档位。效果优先：hero 用 `.cinematic`。
public enum DepthParallaxIntensity: String, Sendable, Equatable {
    case off
    /// Me 体型页等：轻立体
    case subtle
    /// Today 英雄区：明显景深照片感
    case cinematic

    public var backgroundTravel: CGFloat {
        switch self {
        case .off: return 0
        case .subtle: return 16
        case .cinematic: return 36
        }
    }

    public var figureTravel: CGFloat {
        switch self {
        case .off: return 0
        case .subtle: return 7
        case .cinematic: return 14
        }
    }

    public var foregroundTravel: CGFloat {
        switch self {
        case .off: return 0
        case .subtle: return 12
        case .cinematic: return 26
        }
    }

    public var backdropScale: CGFloat {
        switch self {
        case .off: return 1
        case .subtle: return 1.10
        case .cinematic: return 1.20
        }
    }

    public var backgroundBlur: CGFloat {
        switch self {
        case .off: return 0
        case .subtle: return 0.8
        // 位图已有景深；过虚会糊成「假照片」
        case .cinematic: return 1.6
        }
    }

    /// 静止时微幅「呼吸」视差（强化立体；非 360 插值）
    public var ambientAmplitude: CGFloat {
        switch self {
        case .off: return 0
        case .subtle: return 0.14
        case .cinematic: return 0.34
        }
    }
}

/// 归一化视差输入 ∈ [-1, 1]²。纯函数便于测试。
public struct DepthParallaxSample: Equatable, Sendable {
    public var x: CGFloat
    public var y: CGFloat

    public init(x: CGFloat = 0, y: CGFloat = 0) {
        self.x = Self.clamp(x)
        self.y = Self.clamp(y)
    }

    public static func clamp(_ v: CGFloat) -> CGFloat {
        min(1, max(-1, v))
    }

    /// 陀螺 pitch/roll（弧度）→ 样本；roll→x，pitch→y。
    public static func fromAttitude(roll: Double, pitch: Double, gain: Double = 2.4) -> DepthParallaxSample {
        DepthParallaxSample(
            x: CGFloat(roll * gain),
            y: CGFloat(-pitch * gain))
    }

    /// 环境时间相位（秒）→ 慢椭圆，手机静置仍有立体呼吸。
    public static func ambient(time: TimeInterval, amplitude: CGFloat) -> DepthParallaxSample {
        guard amplitude > 0 else { return DepthParallaxSample() }
        let t = time * 0.55
        return DepthParallaxSample(
            x: amplitude * CGFloat(sin(t)),
            y: amplitude * CGFloat(cos(t * 0.73)) * 0.65)
    }

    public func mixed(with other: DepthParallaxSample, otherWeight: CGFloat = 1) -> DepthParallaxSample {
        DepthParallaxSample(
            x: x + other.x * otherWeight,
            y: y + other.y * otherWeight)
    }

    public func offset(travel: CGFloat) -> CGSize {
        CGSize(width: x * travel, height: y * travel)
    }
}

/// iOS 设备姿态 → 视差；macOS/测试为静止 0。
@MainActor
final class DepthParallaxMotion: ObservableObject {
    @Published private(set) var attitude = DepthParallaxSample()

    #if canImport(CoreMotion) && os(iOS)
    private let manager = CMMotionManager()
    #endif

    func start() {
        #if canImport(CoreMotion) && os(iOS)
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data, let self else { return }
            self.attitude = .fromAttitude(
                roll: data.attitude.roll,
                pitch: data.attitude.pitch)
        }
        #endif
    }

    func stop() {
        #if canImport(CoreMotion) && os(iOS)
        manager.stopDeviceMotionUpdates()
        #endif
        attitude = DepthParallaxSample()
    }
}

// MARK: - Layer helpers

enum DepthParallaxLayout {
    static func backgroundOffset(_ s: DepthParallaxSample, intensity: DepthParallaxIntensity) -> CGSize {
        s.offset(travel: intensity.backgroundTravel)
    }

    static func figureOffset(_ s: DepthParallaxSample, intensity: DepthParallaxIntensity) -> CGSize {
        s.offset(travel: intensity.figureTravel)
    }

    static func foregroundOffset(_ s: DepthParallaxSample, intensity: DepthParallaxIntensity) -> CGSize {
        s.offset(travel: intensity.foregroundTravel)
    }
}
