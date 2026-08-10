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
        case .subtle: return 12
        case .cinematic: return 26
        }
    }

    public var figureTravel: CGFloat {
        switch self {
        case .off: return 0
        case .subtle: return 5
        case .cinematic: return 10
        }
    }

    public var foregroundTravel: CGFloat {
        switch self {
        case .off: return 0
        case .subtle: return 9
        case .cinematic: return 18
        }
    }

    public var backdropScale: CGFloat {
        switch self {
        case .off: return 1
        case .subtle: return 1.08
        case .cinematic: return 1.14
        }
    }

    public var backgroundBlur: CGFloat {
        switch self {
        case .off: return 0
        case .subtle: return 0.5
        // 位图自带景深；只做极轻分离
        case .cinematic: return 1.0
        }
    }

    /// 静止时微幅「呼吸」视差（强化立体；非 360 插值）
    public var ambientAmplitude: CGFloat {
        switch self {
        case .off: return 0
        case .subtle: return 0.10
        case .cinematic: return 0.22
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

/// 进程级共享设备姿态源（Apple 明文：全 App 只建**一个** `CMMotionManager` 实例，
/// 多实例互相干扰采样率）。引用计数：首个客户端 attach 启动传感器，最后一个
/// detach（或弱引用清空自愈）停止——列表 N 个 avatar 不再各起一个 manager。
@MainActor
final class SharedDeviceMotion {
    static let shared = SharedDeviceMotion()

    #if canImport(CoreMotion) && os(iOS)
    private let manager = CMMotionManager()
    #endif
    private struct Client {
        weak var owner: AnyObject?
        let fire: (DepthParallaxSample) -> Void
    }
    private var clients: [ObjectIdentifier: Client] = [:]

    var clientCount: Int { clients.count }

    func attach(_ owner: AnyObject, handler: @escaping (DepthParallaxSample) -> Void) {
        let wasEmpty = clients.isEmpty
        clients[ObjectIdentifier(owner)] = Client(owner: owner, fire: handler)
        guard wasEmpty else { return }
        #if canImport(CoreMotion) && os(iOS)
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data, let self else { return }
            self.broadcast(.fromAttitude(
                roll: data.attitude.roll,
                pitch: data.attitude.pitch))
        }
        #endif
    }

    func detach(_ owner: AnyObject) {
        clients.removeValue(forKey: ObjectIdentifier(owner))
        stopIfIdle()
    }

    private func broadcast(_ sample: DepthParallaxSample) {
        // 弱引用自愈：owner 已释放（漏配对 stop）的条目剔除，不让传感器永转。
        clients = clients.filter { $0.value.owner != nil }
        guard !clients.isEmpty else { stopIfIdle(); return }
        for c in clients.values { c.fire(sample) }
    }

    private func stopIfIdle() {
        guard clients.isEmpty else { return }
        #if canImport(CoreMotion) && os(iOS)
        manager.stopDeviceMotionUpdates()
        #endif
    }
}

/// iOS 设备姿态 → 视差；macOS/测试为静止 0。薄壳：委托进程级 `SharedDeviceMotion`，
/// start/stop 幂等（onAppear + onChange 双 start 不重复计数）。
@MainActor
final class DepthParallaxMotion: ObservableObject {
    @Published private(set) var attitude = DepthParallaxSample()
    private let sharedMotion: SharedDeviceMotion
    private var isActive = false

    init(sharedMotion: SharedDeviceMotion = .shared) {
        self.sharedMotion = sharedMotion
    }

    func start() {
        guard !isActive else { return }
        isActive = true
        sharedMotion.attach(self) { [weak self] sample in
            self?.attitude = sample
        }
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        sharedMotion.detach(self)
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
