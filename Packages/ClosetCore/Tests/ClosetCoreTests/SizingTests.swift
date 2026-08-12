import Testing
import Foundation
@testable import ClosetCore

/// D100：`NominalSize` / `SizingCategory` / `MeasurementSchema` / `MeasurementField` /
/// `FlatMeasurements` 已随其零消费者的实现一并删除（复活条件见 Sizing.swift 注释）。
/// 此处只留仍在线上的 `SizeSystem` ——它的 rawValue 落在 `Item.sizeSystemRaw` 里，
/// 是**存储契约**：改一个字母就读不回已存的单品。
struct SizingTests {

    @Test func sizeSystemRawValuesAreAStorageContract() {
        // 这些字符串已落在用户库里——改动 = 读不回已存单品的尺码体系
        #expect(SizeSystem.us.rawValue == "us")
        #expect(SizeSystem.eu.rawValue == "eu")
        #expect(SizeSystem.uk.rawValue == "uk")
        #expect(SizeSystem.jp.rawValue == "jp")
        #expect(SizeSystem.cnGBT.rawValue == "cnGBT")
        #expect(SizeSystem.intl.rawValue == "intl")
        #expect(SizeSystem.allCases.count == 6)
    }

    /// 脏 raw 读回 nil（历史/导入数据可能写进不认识的值），不猜一个体系出来。
    @Test func unknownRawReadsAsNil() {
        #expect(SizeSystem(rawValue: "US") == nil)      // 大小写敏感：落库值就是小写
        #expect(SizeSystem(rawValue: "martian") == nil)
        #expect(SizeSystem(rawValue: "") == nil)
    }
}
