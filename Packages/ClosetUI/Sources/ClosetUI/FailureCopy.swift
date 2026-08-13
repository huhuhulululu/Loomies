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
