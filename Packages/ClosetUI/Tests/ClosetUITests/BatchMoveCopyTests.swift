import Testing
import Foundation
@testable import ClosetUI

/// D174（功能覆盖普查）：批量转移的文案零测试。
///
/// `moveTitle(count:)` 有真逻辑（0 / 1 / 多三种形态），而单复数正是本仓
/// 反复出错的地方（D138 的「1 spot move」、D139 的删柜计数）。
/// `noDestinationMessage` 更要紧：它的注释写着「与单件 Move 同一句
/// （不得两处各写各的）」——**那正是一条只写在注释里的规则**，
/// 而本 session 已经见过太多次它失效（D144 披露两处走岔、D148 排序手抄 19 遍）。
@MainActor
struct BatchMoveCopyTests {

    /// 没选中时不报数（「Move 0 pieces…」是句废话）。
    @Test func nothingSelectedShowsNoCount() {
        #expect(BatchMoveCopy.moveTitle(count: 0) == "Move…")
    }

    /// 单数不写成复数。
    @Test func oneIsSingular() {
        let t = BatchMoveCopy.moveTitle(count: 1)
        #expect(t.contains("1 piece"))
        #expect(!t.contains("pieces"), Comment(rawValue: t))
    }

    /// 复数写成复数。
    @Test func manyArePlural() {
        #expect(BatchMoveCopy.moveTitle(count: 2).contains("2 pieces"))
        #expect(BatchMoveCopy.moveTitle(count: 17).contains("17 pieces"))
    }

    /// **与单件 Move 同源**——注释里的那条规则，现在有人守了。
    /// 两处各写一份的话，用户在两条路上会读到不同的解释。
    @Test func theNoDestinationMessageIsSharedWithSingleMove() {
        #expect(BatchMoveCopy.noDestinationMessage
                == TransferViewModel.noOtherWardrobesMessage)
        #expect(!BatchMoveCopy.noDestinationMessage.isEmpty)
    }

    /// 进出多选态的标签成对且不同（同一个按钮两个状态读起来必须不一样）。
    @Test func theSelectionLabelsAreAPair() {
        #expect(!BatchMoveCopy.enterSelectionLabel.isEmpty)
        #expect(!BatchMoveCopy.exitSelectionLabel.isEmpty)
        #expect(BatchMoveCopy.enterSelectionLabel != BatchMoveCopy.exitSelectionLabel)
    }
}
