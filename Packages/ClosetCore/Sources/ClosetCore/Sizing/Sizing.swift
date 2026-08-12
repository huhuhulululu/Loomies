import Foundation

/// 尺码体系。US 优先展示（en-US 主市场）。
public enum SizeSystem: String, Sendable, CaseIterable {
    case us, eu, uk, jp, cnGBT, intl
}

// D100（缺口 #23）：`NominalSize` / `SizingCategory` / `MeasurementSchema` /
// `MeasurementField` / `FlatMeasurements` 已删除——它们是 F2 时期的**平行设计草稿**，
// 零消费者。真正上线的尺码链路是：`Item.sizeLabel` + `Item.sizeSystemRaw`（标称层，
// 忠实保真不换算）+ `chest/waist/hipFlatWidthInches`（实测层，喂 FitMarkService）
// + `PublicSizeReference`（洗标/条码识别的展示提示）——三者都已接线并有测试。
//
// 复活条件（写在这里，免得下次又凭空重造）：若要做「按品类给出该录哪些平铺字段」
// 的渐进补全 UX，需要先给 Item 加品类字段与稀疏测量存储——那是加法式 schema 变更，
// 走 D84 单向门。git 历史保留了原实现。
