import SwiftUI

/// 底部提示条的状态：显示一句话，到点自己消失（D183）。
///
/// 此前这套「token 自增 + sleep + 比对 token」在三个视图里各写了一份，
/// 时长还各不相同（2s / 3s / 2s），而**日历那一份根本没写**——
/// 它的 `message` 只有赋值没有清除，于是「Planned …」永久压在屏幕底部，
/// 一次删除失败之后即使后续删除成功了，那句「try again」也一直在。
///
/// token 是为了让**后一条接管前一条的定时**：不比对的话，
/// 先来的那条到点时会把后来的一起清掉。
@MainActor
@Observable
public final class FlashState {
    public private(set) var message: String?
    private var token = 0

    public init() {}

    public nonisolated static let defaultSeconds: Double = 2

    public func show(_ message: String?, seconds: Double = defaultSeconds) {
        guard let message, !message.isEmpty else { clear(); return }
        token &+= 1
        let mine = token
        self.message = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if token == mine { self.message = nil }
        }
    }

    public func clear() {
        token &+= 1        // 作废在途的定时，否则它到点会清掉之后新显示的那条
        message = nil
    }
}
