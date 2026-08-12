import Testing
import Foundation
@testable import ClosetUI
import ClosetCore

/// D107：城市辅助输入的状态机。
@MainActor
struct CityPickerViewModelTests {

    /// 录 URL + 给定回包的假传输。
    actor Ledger {
        private(set) var urls: [URL] = []
        func record(_ u: URL) { urls.append(u) }
    }
    struct Stub: PublicAPITransport {
        let ledger = Ledger()
        let payload: Data?
        func get(url: URL) async throws -> Data {
            await ledger.record(url)
            guard let payload else { throw PublicAPIError.notFound }
            return payload
        }
    }

    static let austinJSON = Data("""
    {"results":[{"name":"Austin","latitude":30.27,"longitude":-97.74,
     "country_code":"US","country":"United States","admin1":"Texas",
     "timezone":"America/Chicago"}]}
    """.utf8)

    func vm(_ payload: Data?) -> (CityPickerViewModel, Stub) {
        let stub = Stub(payload: payload)
        let provider = OpenMeteoWeatherProvider(transport: stub)
        return (CityPickerViewModel(provider: provider, debounceMilliseconds: 0), stub)
    }

    /// 选中候选后，存的是**标准名**而不是用户敲的那几个字母。
    @Test func selectingStoresTheCanonicalName() async {
        let (model, _) = vm(Self.austinJSON)
        await model.search("aus")
        let match = try! #require(model.matches.first)
        model.select(match)
        #expect(model.storedValue == "Austin, Texas, United States")
        #expect(model.query == "Austin, Texas, United States")
        #expect(!model.needsResolution)
    }

    /// 选完又改字 → 不再算「已选中」（否则显示的名字与实际存的值对不上）。
    @Test func editingAfterSelectionClearsIt() async {
        let (model, _) = vm(Self.austinJSON)
        await model.search("aus")
        model.select(try! #require(model.matches.first))
        model.query = "Austi"
        model.queryChanged()
        #expect(model.needsResolution)
        #expect(model.storedValue == "Austi")   // 不阻断用户，但会提示去选
    }

    /// 太短不发请求（省流量，也避免把半个国家列出来）。
    @Test func shortQueriesSendNothing() async {
        let (model, stub) = vm(Self.austinJSON)
        model.query = "a"
        model.queryChanged()
        try? await Task.sleep(for: .milliseconds(60))
        #expect(await stub.ledger.urls.isEmpty)
        #expect(model.matches.isEmpty)
    }

    /// 没搜到 = 拼写问题；查不动 = 网络问题。两句话不得混——
    /// 否则用户会以为自己拼错了，反复改一个正确的城市名。
    @Test func noMatchAndFailureAreDifferentSentences() async {
        let (empty, _) = vm(Data(#"{"results":[]}"#.utf8))
        await empty.search("zzzzzz")
        #expect(empty.message == CitySearch.noMatchMessage)

        let (broken, _) = vm(nil)   // transport 抛错
        await broken.search("Austin")
        #expect(broken.message == CitySearch.searchFailedMessage)
        #expect(broken.message != CitySearch.noMatchMessage)
    }

    /// 载入既有衣柜的城市：显示出来，但仍需用户确认才算「已解析」。
    @Test func preloadShowsExistingValueUnresolved() {
        let (model, _) = vm(Self.austinJSON)
        model.preload("Austin, Texas, United States")
        #expect(model.query == "Austin, Texas, United States")
        #expect(model.storedValue == "Austin, Texas, United States")
        #expect(model.needsResolution)   // 没从列表选过 → 提示仍在
    }

    /// 空值不硬塞——用户清空就是清空。
    @Test func clearingYieldsNil() {
        let (model, _) = vm(Self.austinJSON)
        model.preload("   ")
        #expect(model.storedValue == nil)
        #expect(!model.needsResolution)
    }
}
