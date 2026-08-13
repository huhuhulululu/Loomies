import Foundation

/// 「什么算用户内容」的**唯一定义**（D165）。
///
/// 遥测门（值里不得读用户内容）与 AppLog PII 门（插值里不得读用户内容）
/// 此前各有一张手工枚举的表，于是各自过期：实测遥测门抓不到
/// `"closet_name": wardrobe.name`（键名不匹配），PII 门抓不到
/// `\(item.brand` / `\(item.notes`（模式表里没有）。
///
/// 两张表合成一张，并由 `TelemetryGateTests.theUserContentListTracksTheSchema`
/// 守着与 schema 同步——加了新的用户输入字段而没纳入，那道门会红。
enum UserContentFields {
    /// 属性访问形态（`.name` 而不是 `name`），避免误伤 `"has_text"` 这类布尔化的键。
    static let reads = [
        ".name", ".notes", ".text", ".query", "locationCity",
        "bustInches", "waistInches", "hipInches", "highHipInches",
        ".sizeLabel", ".brand", ".barcode",
    ]
}
