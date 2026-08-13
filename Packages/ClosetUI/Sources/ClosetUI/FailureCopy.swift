import Foundation

/// 失败文案的分类（D128）。
///
/// 全仓 40 处失败提示，几乎每一条都以「— try again」收尾——
/// **包括那些重试也没用的**：磁盘满了重试一百次还是满的；
/// 「这不是 Loomies 的导出文件」再点一次也不会变成。
///
/// 把「重试」当万能结尾，等于把用户往一条走不通的路上推，
/// 而他会一直点，直到以为 App 坏了。
///
/// 分类的判据只有一个：**再做一次同样的动作，有没有可能成功**。
public enum FailureCopy {

    public enum Kind: Equatable, Sendable {
        /// 偶发：磁盘忙、一次写入没成、网络抖动。再试一次真的可能成。
        case transient(String)
        /// 要用户先做点别的，才谈得上重试。`next` 是那件事。
        case needsUserAction(String, next: String)
        /// 空间不足——重试无意义，得先腾地方。
        case outOfSpace
    }

    /// 带**结果位**的用户消息（D137）。
    ///
    /// `CustomerFlashStyle.isFailure` 是靠关键词嗅探（"couldn't"/"failed"…），
    /// 而 D128/D129 把文案改成了不带那些词的说法
    /// （「No body preview yet…」「That's the full backup (a .zip)」）——
    /// 于是**失败被画成了成功的底色**。
    /// 往关键词表里加词只会让下一条文案再掉进去：结果性必须由**产生它的代码**带出来。
    public struct Message: Equatable, Sendable {
        public let text: String
        public let isFailure: Bool
        public init(text: String, isFailure: Bool) {
            self.text = text
            self.isFailure = isFailure
        }
        public static func failure(_ kind: Kind) -> Message {
            Message(text: line(kind), isFailure: true)
        }
        public static func success(_ text: String) -> Message {
            Message(text: text, isFailure: false)
        }
    }

    public static func line(_ kind: Kind) -> String {
        switch kind {
        case .transient(let what):
            return "\(what) — try again"
        case .needsUserAction(let what, let next):
            // 刻意**不含**「try again」：那会把用户推回一条走不通的路
            return "\(what). \(next)."
        case .outOfSpace:
            return "Not enough space on this device. Free some up, then try that again."
        }
    }
}
