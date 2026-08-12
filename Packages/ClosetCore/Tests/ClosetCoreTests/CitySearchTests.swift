import Testing
import Foundation
@testable import ClosetCore

/// D107（用户反馈：「客户的地址对应的标准名 辅助输入」）：
/// 城市此前是**纯自由文本**——没有联想、没有标准名、拼错了也不告诉你，
/// 而 geocoding 一直在跑，只是 `count=1` 取第一条、`admin1`/`country` 直接丢弃。
/// 于是「Springfield」到底是哪一个，用户和 App 都不知道。
struct CitySearchTests {

    func payload(_ results: String) -> Data {
        Data("""
        {"results":[\(results)]}
        """.utf8)
    }

    let austin = """
    {"name":"Austin","latitude":30.27,"longitude":-97.74,
     "country_code":"US","country":"United States","admin1":"Texas",
     "timezone":"America/Chicago"}
    """

    /// 标准名要能把同名城市分开——这是「辅助输入」的全部意义。
    @Test func canonicalNameCarriesRegionAndCountry() throws {
        let matches = try OpenMeteoJSON.parseGeocodeMatches(payload(austin))
        let m = try #require(matches.first)
        #expect(m.city == "Austin")
        #expect(m.displayName == "Austin, Texas, United States")
        #expect(m.timezone == "America/Chicago")
    }

    /// 缺 admin1 时降级但不留悬空逗号（很多国家没有二级行政区）。
    @Test func missingRegionDegradesCleanly() throws {
        let noAdmin = """
        {"name":"Singapore","latitude":1.29,"longitude":103.85,
         "country_code":"SG","country":"Singapore","timezone":"Asia/Singapore"}
        """
        let m = try #require(try OpenMeteoJSON.parseGeocodeMatches(payload(noAdmin)).first)
        #expect(m.displayName == "Singapore, Singapore")
        #expect(!m.displayName.contains(", ,"))
    }

    /// 同名城市必须**各自可分辨**（Springfield 问题）。
    @Test func sameNameCitiesAreDistinguishable() throws {
        let two = """
        {"name":"Springfield","latitude":39.8,"longitude":-89.6,
         "country_code":"US","country":"United States","admin1":"Illinois"},
        {"name":"Springfield","latitude":42.1,"longitude":-72.6,
         "country_code":"US","country":"United States","admin1":"Massachusetts"}
        """
        let matches = try OpenMeteoJSON.parseGeocodeMatches(payload(two))
        #expect(matches.count == 2)
        #expect(Set(matches.map(\.displayName)).count == 2)
    }

    /// 顺序确定（同名同区时按坐标决胜）——候选列表不得每次抖动。
    @Test func matchOrderIsDeterministic() throws {
        let dup = """
        {"name":"Springfield","latitude":42.1,"longitude":-72.6,
         "country_code":"US","country":"United States","admin1":"Massachusetts"},
        {"name":"Springfield","latitude":39.8,"longitude":-89.6,
         "country_code":"US","country":"United States","admin1":"Illinois"}
        """
        let a = try OpenMeteoJSON.parseGeocodeMatches(payload(dup))
        let b = try OpenMeteoJSON.parseGeocodeMatches(payload(dup))
        #expect(a.map(\.displayName) == b.map(\.displayName))
    }

    /// 没有结果 = 没有结果（不得编一个出来，也不得抛错让 UI 显示「网络错误」）。
    @Test func noResultsIsEmptyNotAnError() throws {
        #expect(try OpenMeteoJSON.parseGeocodeMatches(Data(#"{"results":[]}"#.utf8)).isEmpty)
        #expect(try OpenMeteoJSON.parseGeocodeMatches(Data("{}".utf8)).isEmpty)
    }

    /// 坏数据仍然抛（与既有 parse 一致），但空结果不算坏数据。
    @Test func corruptPayloadStillThrows() {
        #expect(throws: (any Error).self) {
            try OpenMeteoJSON.parseGeocodeMatches(Data("not json".utf8))
        }
    }

    /// 缺坐标的条目跳过——不得让一个无坐标的城市进候选然后查不了天气。
    @Test func entriesWithoutCoordinatesAreSkipped() throws {
        let broken = """
        {"name":"Nowhere","country":"Atlantis"},
        \(austin)
        """
        let matches = try OpenMeteoJSON.parseGeocodeMatches(payload(broken))
        #expect(matches.count == 1)
        #expect(matches.first?.city == "Austin")
    }

    /// 空白/超短输入不发请求（省一次网络，也避免把整个国家列出来）。
    @Test func queriesTooShortAreNotWorthSending() {
        #expect(!CitySearch.isWorthSearching(""))
        #expect(!CitySearch.isWorthSearching("  "))
        #expect(!CitySearch.isWorthSearching("a"))
        #expect(CitySearch.isWorthSearching("au"))
        #expect(CitySearch.isWorthSearching(" Austin "))
    }

    /// 存进衣柜的是**标准名**——下次 geocode 不再有歧义。
    @Test func storedValueIsTheCanonicalName() throws {
        let m = try #require(try OpenMeteoJSON.parseGeocodeMatches(payload(austin)).first)
        #expect(CitySearch.storedValue(for: m) == "Austin, Texas, United States")
    }
}
