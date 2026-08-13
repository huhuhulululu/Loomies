import Testing
import Foundation
@testable import ClosetCore

/// D123：**每一件都靠手打**。识别与洗标 OCR 是永久 mock（`recognitionAvailable == false`），
/// 而 MVP-PLAN 的「首日 50 件」目标建立在录入足够轻上——
/// 一件件敲品牌和尺码，那个目标不成立。
///
/// 这一层是**纯解析**：拿到 OCR 出来的若干行文字，认出哪一行是品牌、哪个 token 是尺码。
/// Vision 那一层是平台胶水（`#if canImport(Vision)`，`swift test` 编不到），
/// 但「认得准不准」全在这里，可以被真实洗标文本钉住。
///
/// 判断标准是**宁缺勿错**：填错一个尺码比留空更糟——留空用户会填，
/// 填错了他不会去核对。所以每条规则都往「不确定就不填」的方向倒。
struct LabelTextParserTests {

    // MARK: - 尺码

    @Test func itFindsAPlainLetterSize() {
        #expect(LabelTextParser.parse(lines: ["100% COTTON", "M"]).size == "M")
        #expect(LabelTextParser.parse(lines: ["SIZE XL"]).size == "XL")
        #expect(LabelTextParser.parse(lines: ["Size: S"]).size == "S")
    }

    @Test func itFindsNumericSizes() {
        #expect(LabelTextParser.parse(lines: ["SIZE 8"]).size == "8")
        #expect(LabelTextParser.parse(lines: ["W32 L34"]).size == "W32 L34")
        #expect(LabelTextParser.parse(lines: ["EUR 38 / US 6"]).size == "US 6")
    }

    /// **成分表里的数字不是尺码**——「95% cotton 5% elastane」不能被读成尺码 95。
    @Test func fabricPercentagesAreNotSizes() {
        let info = LabelTextParser.parse(lines: [
            "95% COTTON", "5% ELASTANE", "MADE IN PORTUGAL",
        ])
        #expect(info.size == nil, Comment(rawValue: "成分表被当成尺码：\(info.size ?? "")"))
    }

    /// 洗涤温度也不是尺码。
    @Test func washTemperaturesAreNotSizes() {
        #expect(LabelTextParser.parse(lines: ["WASH 30", "DO NOT BLEACH"]).size == nil)
        #expect(LabelTextParser.parse(lines: ["30°C"]).size == nil)
    }

    /// RN/CA 之类的监管编号不是尺码。
    @Test func regulatoryNumbersAreNotSizes() {
        #expect(LabelTextParser.parse(lines: ["RN 12345", "CA 54321"]).size == nil)
    }

    // MARK: - 品牌

    /// 品牌通常是**独占一行的短词**，且不是成分/护理/产地术语。
    @Test func itPicksTheBrandLine() {
        let info = LabelTextParser.parse(lines: [
            "EVERLANE", "100% COTTON", "MADE IN VIETNAM", "M",
        ])
        #expect(info.brand == "Everlane")
    }

    /// 护理与产地术语一律不是品牌。
    @Test func careAndOriginTermsAreNeverTheBrand() {
        for line in ["MACHINE WASH COLD", "MADE IN ITALY", "DRY CLEAN ONLY",
                     "100% WOOL", "TUMBLE DRY LOW", "EXCLUSIVE OF DECORATION"] {
            let info = LabelTextParser.parse(lines: [line, "M"])
            #expect(info.brand == nil, Comment(rawValue: "把「\(line)」当成了品牌"))
        }
    }

    /// 太长的行不是品牌（那是说明文字）。
    @Test func aLongSentenceIsNotABrand() {
        let info = LabelTextParser.parse(lines: [
            "KEEP AWAY FROM FIRE AND OPEN FLAME SOURCES", "M",
        ])
        #expect(info.brand == nil)
    }

    /// 首字母大写规范化——洗标全大写，而用户列表里想看「Everlane」不是「EVERLANE」。
    @Test func theBrandIsNormalisedForDisplay() {
        #expect(LabelTextParser.parse(lines: ["COS"]).brand == "COS")        // 短缩写保持原样
        #expect(LabelTextParser.parse(lines: ["UNIQLO"]).brand == "Uniqlo")
        #expect(LabelTextParser.parse(lines: ["Acne Studios"]).brand == "Acne Studios")
    }

    // MARK: - 宁缺勿错

    @Test func nothingRecognisableYieldsNothing() {
        let info = LabelTextParser.parse(lines: ["◆◆◆", "|||", ""])
        #expect(info.brand == nil)
        #expect(info.size == nil)
    }

    @Test func emptyInputIsSafe() {
        let info = LabelTextParser.parse(lines: [])
        #expect(info.brand == nil)
        #expect(info.size == nil)
    }

    /// 同一张标里既有品牌又有尺码时两个都要认出来（这才算省了用户的事）。
    @Test func aRealisticLabelYieldsBoth() {
        let info = LabelTextParser.parse(lines: [
            "UNIQLO", "SIZE M", "100% COTTON", "MADE IN CHINA",
            "MACHINE WASH COLD", "RN 122345",
        ])
        #expect(info.brand == "Uniqlo")
        #expect(info.size == "M")
    }

    /// 结果确定：同样的输入两次得到同样的输出（顺序不得随集合遍历漂移）。
    @Test func parsingIsDeterministic() {
        let lines = ["COS", "ACNE", "SIZE M", "SIZE L"]
        let a = LabelTextParser.parse(lines: lines)
        let b = LabelTextParser.parse(lines: lines)
        #expect(a.brand == b.brand)
        #expect(a.size == b.size)
    }
}

/// D137：品牌判定是「首个通过黑名单的短行」——而黑名单永远不完整。
/// 实际后果：单品被命名为「Shell Top」「Do Not Wring Outerwear」
/// 「RN12345 Top」「Navy Top」，品牌字段同值，而**那正是搜索匹配的字段**。
struct LabelBrandFalsePositiveTests {

    /// 部件名词不是品牌（洗标上「SHELL / LINING / BODY」是面料分区）。
    @Test func garmentPartsAreNotBrands() {
        for line in ["SHELL", "LINING", "BODY", "TRIM"] {
            #expect(LabelTextParser.parse(lines: [line, "M"]).brand == nil,
                    Comment(rawValue: "「\(line)」被当成了品牌"))
        }
    }

    /// 护理动词短语不是品牌。
    @Test func careVerbsAreNotBrands() {
        for line in ["DO NOT WRING", "TURN INSIDE OUT", "NO CHLORINE", "REMOVE PROMPTLY"] {
            #expect(LabelTextParser.parse(lines: [line, "M"]).brand == nil,
                    Comment(rawValue: "「\(line)」被当成了品牌"))
        }
    }

    /// 监管号不是品牌——**不带空格的 `RN12345` 此前从整词黑名单里逃逸**。
    @Test func regulatoryNumbersAreNotBrands() {
        for line in ["RN12345", "RN#12345", "CA54321", "WPL9876"] {
            #expect(LabelTextParser.parse(lines: [line]).brand == nil,
                    Comment(rawValue: "「\(line)」被当成了品牌"))
        }
    }

    /// 整行是颜色名的不是品牌（洗标常印颜色）。
    @Test func colourNamesAreNotBrands() {
        for line in ["NAVY", "Black", "OLIVE"] {
            #expect(LabelTextParser.parse(lines: [line, "M"]).brand == nil,
                    Comment(rawValue: "「\(line)」被当成了品牌"))
        }
    }

    /// **拿不准就不给**：有多个候选行时返回 nil——
    /// 黑名单永远不完整，宁缺勿错才是这一层的判断标准。
    @Test func ambiguousLabelsYieldNoBrand() {
        let info = LabelTextParser.parse(lines: ["EVERLANE", "ATELIER", "SIZE M"])
        #expect(info.brand == nil, Comment(rawValue: "两个候选却挑了一个：\(info.brand ?? "")"))
        #expect(info.size == "M", "尺码不该受影响")
    }

    /// 只有一个候选时照常给（别把有用的能力一起关掉）。
    @Test func aSingleCandidateStillResolves() {
        #expect(LabelTextParser.parse(lines: [
            "UNIQLO", "100% COTTON", "MADE IN CHINA", "SIZE M",
        ]).brand == "Uniqlo")
    }
}
