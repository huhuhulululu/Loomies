import Testing
import Foundation
@testable import ClosetCore

/// D108（用户反馈：「还有很多的要排查优化」）：数值录入此前用 `Double(String)` 直解，
/// 小数逗号地区（德/法/西/俄…）输入「15,5」得到 nil——**值无声消失**，
/// 没有报错也没有提示，保存后字段变空。字段用的还是默认字母键盘。
struct MeasurementEntryTests {

    let de = Locale(identifier: "de_DE")   // 小数逗号 + 点作分组
    let us = Locale(identifier: "en_US")

    // MARK: - 解析

    @Test func decimalCommaLocaleParsesItsOwnFormat() {
        #expect(MeasurementEntry.parse("15,5", locale: de) == 15.5)
        #expect(MeasurementEntry.parse("15.5", locale: us) == 15.5)
    }

    /// 用户可能从网页复制另一种写法——不该因此丢值。
    @Test func theOtherNotationIsAlsoAccepted() {
        #expect(MeasurementEntry.parse("15.5", locale: de) == 15.5)
        #expect(MeasurementEntry.parse("15,5", locale: us) == 15.5)
    }

    /// 分组分隔符与空白不影响（「1 234,5」「1,234.5」）。
    @Test func groupingAndWhitespaceAreTolerated() {
        #expect(MeasurementEntry.parse("1.234,5", locale: de) == 1234.5)
        #expect(MeasurementEntry.parse("1,234.5", locale: us) == 1234.5)
        #expect(MeasurementEntry.parse(" 42 ", locale: us) == 42)
    }

    /// 真的不是数就是 nil（不是「分隔符不对」而已）。
    @Test func nonNumbersAreNil() {
        for junk in ["abc", "--", "1.2.3.4.5", ""] {
            #expect(MeasurementEntry.parse(junk, locale: us) == nil,
                    Comment(rawValue: "误判为数字：\(junk)"))
        }
        #expect(MeasurementEntry.parse("   ", locale: us) == nil)
    }

    /// 非有限值不得进来（NaN/inf 会让合身判定失效）。
    @Test func nonFiniteIsRejected() {
        #expect(MeasurementEntry.parse("inf", locale: us) == nil)
        #expect(MeasurementEntry.parse("nan", locale: us) == nil)
    }

    // MARK: - 单位换算

    @Test func centimetersConvertToStoredInches() {
        let inches = try! #require(
            MeasurementEntry.inches(from: "25,4", unit: .centimeters, locale: de))
        #expect(abs(inches - 10) < 0.001)
    }

    @Test func inchesStayInches() {
        #expect(MeasurementEntry.inches(from: "10", unit: .inches, locale: us) == 10)
    }

    /// 非正值即缺失（0/负数不是测量值，`ItemEditorService` 也会拒）。
    @Test func nonPositiveIsTreatedAsMissing() {
        #expect(MeasurementEntry.inches(from: "0", unit: .inches, locale: us) == nil)
        #expect(MeasurementEntry.inches(from: "-3", unit: .inches, locale: us) == nil)
    }

    // MARK: - 回显

    /// 往返：存进去再显示出来，用户看到的还是他输入的那个数。
    @Test func roundTripsThroughTheUsersUnit() {
        for unit in MeasurementEntry.Unit.allCases {
            let stored = MeasurementEntry.inches(from: "16", unit: unit, locale: us)
            #expect(MeasurementEntry.text(fromInches: stored, unit: unit) == "16")
        }
    }

    /// 浮点噪音不得出现在输入框里（`15.000000000000002`）。
    @Test func displayHasNoFloatingPointNoise() {
        let stored = MeasurementEntry.inches(from: "15.5", unit: .centimeters, locale: us)
        let shown = MeasurementEntry.text(fromInches: stored, unit: .centimeters)
        #expect(shown == "15.5")
        #expect(!shown.contains("0000"))
    }

    @Test func nilShowsAsEmptyNotZero() {
        #expect(MeasurementEntry.text(fromInches: nil, unit: .inches) == "")
        #expect(MeasurementEntry.text(fromInches: .nan, unit: .inches) == "")
    }

    // MARK: - 提示

    /// 占位符带单位——用户不必猜要填英寸还是厘米。
    @Test func placeholderNamesTheUnit() {
        #expect(MeasurementEntry.placeholder("Chest", unit: .inches).contains("in"))
        #expect(MeasurementEntry.placeholder("Chest", unit: .centimeters).contains("cm"))
    }

    /// 输入了但解析不出来 → 当场说，而不是保存后字段变空。
    @Test func unparseableInputIsFlaggedNotSwallowed() {
        #expect(MeasurementEntry.isUnparseable("abc", locale: us))
        #expect(!MeasurementEntry.isUnparseable("15,5", locale: de))
        // 空输入不算错（清空是合法操作）
        #expect(!MeasurementEntry.isUnparseable("", locale: us))
        #expect(!MeasurementEntry.isUnparseable("  ", locale: us))
        #expect(!MeasurementEntry.unparseableMessage.isEmpty)
    }
}
