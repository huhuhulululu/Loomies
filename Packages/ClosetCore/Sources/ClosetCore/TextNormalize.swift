import Foundation

/// 可选文本字段的统一归一：所有「空白即缺失」判定与落库前转换走这里，
/// 消除 trim 与不 trim 两套标准并存（brand/size 曾因 " " 阻塞条码补全）。
public enum TextNormalize {
    /// Trim 后为空 → nil；否则返回 trim 后的值。
    public static func blankToNil(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
            return nil
        }
        return t
    }

    /// nil 或 trim 后为空。
    public static func isBlank(_ s: String?) -> Bool { blankToNil(s) == nil }
}
