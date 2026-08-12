import Foundation

/// 测量值的**录入解析与显示**（D108）。
///
/// 此前所有数值字段都用 `Double(String)` 直解：在小数逗号地区（德/法/西/俄…）
/// 用户输入「15,5」会得到 nil，**值就这么无声消失了**——没有报错、没有提示，
/// 保存后字段变空。而字段用的还是默认字母键盘。
///
/// 单位同理：详情页写死「inches」，而 `PersonBodyProfile` 那边早有公制偏好。
public enum MeasurementEntry {

    /// 长度单位。存储层**一律英寸**（既有数据如此），只在录入/显示处换算。
    public enum Unit: String, Sendable, CaseIterable {
        case inches, centimeters

        public var suffix: String {
            switch self {
            case .inches: return "in"
            case .centimeters: return "cm"
            }
        }

        /// 该单位下 1 个刻度等于多少英寸。
        public var inchesPerUnit: Double {
            switch self {
            case .inches: return 1
            case .centimeters: return 1 / 2.54
            }
        }
    }

    /// 宽松解析：接受该地区的小数分隔符，也接受另一种写法
    /// （用户可能从网页复制「15.5」到一个逗号地区的设备上）。
    /// 返回 nil = 真的不是一个数，而不是「分隔符不对」。
    public static func parse(_ raw: String, locale: Locale = .current) -> Double? {
        guard let text = TextNormalize.blankToNil(raw) else { return nil }
        var s = text.filter { !$0.isWhitespace }
        let dots = s.filter { $0 == "." }.count
        let commas = s.filter { $0 == "," }.count

        // 判定哪个是小数点：**按位置**，不按地区——用户可能从网页粘贴另一种写法，
        // 而先剥「本地分组符」会把 de 下的「15.5」误读成 155（本波实测踩到）。
        if dots > 0, commas > 0 {
            // 两种都在：**最后出现**的那个是小数点，另一个是分组
            let lastDot = s.lastIndex(of: ".")!
            let lastComma = s.lastIndex(of: ",")!
            let decimalIsDot = lastDot > lastComma
            s = s.replacingOccurrences(of: decimalIsDot ? "," : ".", with: "")
            if !decimalIsDot { s = s.replacingOccurrences(of: ",", with: ".") }
        } else if commas > 1 || dots > 1 {
            // 只有一种但出现多次：**只有每段恰好 3 位**才是分组（「1.234.567」）。
            // 「1.2.3.4.5」不是数字，不该被剥成 12345。
            let sep: Character = commas > 1 ? "," : "."
            let parts = s.split(separator: sep, omittingEmptySubsequences: false)
            let looksLikeGrouping = parts.count > 1
                && parts.dropFirst().allSatisfy { $0.count == 3 }
                && (1...3).contains(parts[0].count)
                && parts.allSatisfy { $0.allSatisfy(\.isNumber) }
            guard looksLikeGrouping else { return nil }
            s = s.replacingOccurrences(of: String(sep), with: "")
        } else if commas == 1 {
            // 只出现一次的分隔符按**小数点**解：本域的值都是衣物/身体尺寸，
            // 「1,234 英寸」不是真实输入，而把 15,5 读成 155 会毁掉一次录入。
            s = s.replacingOccurrences(of: ",", with: ".")
        }
        _ = locale   // 判定不依赖地区，保留参数以便将来需要时按地区收紧
        guard let value = Double(s), value.isFinite else { return nil }
        return value
    }

    /// 录入值（用户单位）→ 存储值（英寸）。非有限/非正返回 nil（脏值即缺失）。
    public static func inches(from raw: String, unit: Unit, locale: Locale = .current) -> Double? {
        guard let value = parse(raw, locale: locale), value > 0 else { return nil }
        let inches = value * unit.inchesPerUnit
        return inches.isFinite ? inches : nil
    }

    /// 存储值（英寸）→ 录入框文字（用户单位）。nil → 空串。
    /// 最多一位小数：`15.000000000000002` 这种浮点噪音不该出现在输入框里。
    public static func text(fromInches inches: Double?, unit: Unit) -> String {
        guard let inches, inches.isFinite else { return "" }
        let value = inches / unit.inchesPerUnit
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
    }

    /// 字段占位符带上单位，用户不必猜。
    public static func placeholder(_ label: String, unit: Unit) -> String {
        "\(label) (\(unit.suffix))"
    }

    /// 输入了东西但解析不出来时的诚实提示——此前是静默丢弃。
    public static let unparseableMessage = "That doesn't look like a number — check the value."

    /// 输入非空但解析失败（用于 UI 即时提示；空输入不算错）。
    public static func isUnparseable(_ raw: String, locale: Locale = .current) -> Bool {
        guard TextNormalize.blankToNil(raw) != nil else { return false }
        return parse(raw, locale: locale) == nil
    }
}
