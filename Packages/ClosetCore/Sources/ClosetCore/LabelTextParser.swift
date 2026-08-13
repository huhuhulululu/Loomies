import Foundation

/// 洗标文本解析（D123）。
///
/// 识别与 OCR 此前是永久 mock，**每一件都靠手打**——而 MVP-PLAN 的「首日 50 件」
/// 建立在录入足够轻上，一件件敲品牌和尺码那个目标不成立。
///
/// 这一层是纯解析：Vision 给出若干行文字，认出哪行是品牌、哪个 token 是尺码。
/// 平台那层（`RecognizeTextRequest`）是胶水，「认得准不准」全在这里。
///
/// 贯穿始终的判断标准是**宁缺勿错**：填错一个尺码比留空更糟——
/// 留空用户会填，填错了他不会去核对。每条规则都往「不确定就不填」倒。
public enum LabelTextParser {

    public struct Parsed: Equatable, Sendable {
        public let brand: String?
        public let size: String?
        public init(brand: String?, size: String?) {
            self.brand = brand
            self.size = size
        }
    }

    /// 护理 / 成分 / 产地 / 监管术语——出现这些词的行一律不是品牌。
    private static let nonBrandTerms: Set<String> = [
        "wash", "washing", "bleach", "tumble", "dry", "iron", "clean", "dryclean",
        "cotton", "wool", "polyester", "elastane", "spandex", "nylon", "viscose",
        "linen", "silk", "cashmere", "rayon", "acrylic", "modal", "lyocell",
        "made", "origin", "imported", "exclusive", "decoration", "fabric",
        "size", "taille", "talla", "keep", "away", "fire", "flame", "care",
        "professional", "hand", "machine", "cold", "warm", "hot", "low", "medium",
        "rn", "ca", "wpl", "style", "color", "colour",
        // D137：部件名词（洗标上是面料分区，不是牌子）
        "shell", "lining", "body", "trim", "filling", "padding",
        // D137：护理动词短语
        "wring", "turn", "inside", "remove", "promptly", "chlorine",
        "bleach", "reshape", "flat", "line", "shade", "steam",
    ]

    /// 字母尺码。
    private static let letterSizes: Set<String> = [
        "XXS", "XS", "S", "M", "L", "XL", "XXL", "XXXL", "2XL", "3XL",
    ]

    public static func parse(lines: [String]) -> Parsed {
        let cleaned = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Parsed(brand: brand(in: cleaned), size: size(in: cleaned))
    }

    // MARK: - 尺码

    static func size(in lines: [String]) -> String? {
        // 1) 明确写了 SIZE 的行最可信
        for line in lines {
            let upper = line.uppercased()
            guard upper.contains("SIZE") else { continue }
            let rest = upper
                .replacingOccurrences(of: "SIZE", with: " ")
                .replacingOccurrences(of: ":", with: " ")
                .trimmingCharacters(in: .whitespaces)
            if let token = firstSizeToken(in: rest) { return token }
        }
        // 2) 腰长组合（W32 L34）——牛仔裤标上很常见，且不会与别的数字混淆
        for line in lines {
            let upper = line.uppercased()
            if let range = upper.range(
                of: #"\bW\s?\d{2}\s*/?\s*L\s?\d{2}\b"#, options: .regularExpression) {
                return String(upper[range])
                    .replacingOccurrences(of: "/", with: " ")
                    .replacingOccurrences(of: "  ", with: " ")
            }
        }
        // 3) 带国家前缀的（US 6 / UK 10）——前缀让它区别于成分和温度
        for line in lines {
            let upper = line.uppercased()
            if let range = upper.range(
                of: #"\b(US|UK)\s?\d{1,2}\b"#, options: .regularExpression) {
                return String(upper[range]).replacingOccurrences(of: "  ", with: " ")
            }
        }
        // 4) 独占一行的字母尺码
        for line in lines {
            let upper = line.uppercased().trimmingCharacters(in: .whitespaces)
            if letterSizes.contains(upper) { return upper }
        }
        // 光有数字**不算**——成分百分比、洗涤温度、RN 编号都是数字，
        // 认错一个尺码比留空更糟。
        return nil
    }

    private static func firstSizeToken(in text: String) -> String? {
        for token in text.split(whereSeparator: { $0 == " " || $0 == "/" }) {
            let t = String(token)
            if letterSizes.contains(t) { return t }
            if t.count <= 3, t.allSatisfy(\.isNumber), let n = Int(t), (0...60).contains(n) {
                return t
            }
        }
        return nil
    }

    // MARK: - 品牌

    /// 品牌。
    ///
    /// D137：此前是「首个通过黑名单的短行」——而**黑名单永远不完整**，
    /// 于是「SHELL」「RN12345」「NAVY」都成了品牌，
    /// 单品被命名为「Shell Top」「Navy Top」，而品牌正是搜索匹配的字段。
    ///
    /// 改成**唯一候选才给**：拿不准就不给，这才是「宁缺勿错」的正确形态——
    /// 靠往黑名单里加词永远补不完，而每漏一个词就错一件衣服。
    static func brand(in lines: [String]) -> String? {
        var candidates: [String] = []
        for line in lines {
            let words = line.split(separator: " ").map(String.init)
            // 品牌是独占一行的**短**词组；长句是说明文字
            guard (1...3).contains(words.count), line.count <= 24 else { continue }
            // 含护理/成分/产地/监管术语 → 不是品牌
            let lowered = words.map { $0.lowercased().trimmingCharacters(
                in: CharacterSet.alphanumerics.inverted) }
            if lowered.contains(where: { nonBrandTerms.contains($0) }) { continue }
            // 纯数字 / 含百分号 / 含度数 → 不是品牌
            if line.contains("%") || line.contains("°") { continue }
            if words.allSatisfy({ $0.allSatisfy { !$0.isLetter } }) { continue }
            // 字母尺码本身也不是品牌
            if letterSizes.contains(line.uppercased()) { continue }
            // 至少要有两个字母（"◆◆" 之类过不了）
            guard line.filter(\.isLetter).count >= 2 else { continue }
            // 监管号：`RN12345` 这种不带空格的会从整词黑名单里逃逸
            let squashed = line.lowercased().filter { $0.isLetter || $0.isNumber }
            if squashed.range(of: #"^(rn|ca|wpl)\d+$"#, options: .regularExpression) != nil {
                continue
            }
            // 整行是颜色名的不是品牌（洗标常印颜色）——复用色板，不另起一张表
            let bare = line.lowercased().trimmingCharacters(in: .whitespaces)
            if GarmentColorPalette.entries.contains(where: { $0.id == bare || $0.title.lowercased() == bare }) {
                continue
            }
            candidates.append(line)
        }
        // 多个候选 = 拿不准。给错一个品牌比留空更糟：留空用户会填，
        // 填错了他不会去核对，而搜索匹配的正是这个字段。
        guard candidates.count == 1, let only = candidates.first else { return nil }
        return displayName(only)
    }

    /// 洗标全大写，而列表里想看的是「Everlane」不是「EVERLANE」。
    /// 但 4 个字母以内的全大写保持原样——那多半是缩写（COS、NA-KD）。
    static func displayName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let isAllCaps = trimmed == trimmed.uppercased()
        guard isAllCaps, trimmed.filter(\.isLetter).count > 4 else { return trimmed }
        // D141：按**字母段**大写，不按空格切词。
        // 按空格切的话 `J.CREW` 是一个词 → `J` + `.crew` = 「J.crew」，
        // `L.L.BEAN` → 「L.l.bean」——而品牌是检索页的匹配字段（D120 的 #1 JTBD），
        // 洗标 OCR 又正是它的主要来源。按字母段处理，`L.L.Bean` /
        // `Saint-Laurent` 这类名字自己就对了，分隔符原样留着。
        var out = ""
        var startOfWord = true
        for ch in trimmed {
            if ch.isLetter {
                out.append(startOfWord ? ch : Character(ch.lowercased()))
                startOfWord = false
            } else {
                out.append(ch)
                startOfWord = true      // 空格/点/连字符之后都是新的一段
            }
        }
        return out
    }
}
