import SwiftUI
import Observation
import ClosetCore

/// 城市辅助输入（D107）。此前是纯自由文本：没有联想、没有标准名、拼错了也不告诉你。
/// 选中候选后存的是**标准名**（"Austin, Texas, United States"），
/// 下次 geocode 不再有歧义——同名城市也终于分得开。
@MainActor
@Observable
public final class CityPickerViewModel {
    /// 用户正在输入的文字。
    public var query: String = ""
    public private(set) var matches: [CityMatch] = []
    public private(set) var isSearching = false
    public private(set) var message = ""
    /// 已选中的标准名；nil = 还没从列表里选过。
    public private(set) var selected: CityMatch?

    private let provider: OpenMeteoWeatherProvider
    private var searchTask: Task<Void, Never>?
    /// 防抖：每敲一个字母就发一次请求既费流量也没必要。
    private let debounce: Duration

    public init(
        provider: OpenMeteoWeatherProvider = OpenMeteoWeatherProvider(),
        debounceMilliseconds: Int = 300
    ) {
        self.provider = provider
        self.debounce = .milliseconds(max(0, debounceMilliseconds))
    }

    /// 已确定要存的值：选过就是标准名；没选过就用原文（不阻断用户）。
    public var storedValue: String? {
        if let selected { return CitySearch.storedValue(for: selected) }
        return TextNormalize.blankToNil(query)
    }

    /// 用户是否还欠一次选择（UI 据此给提示，而不是默默用一个没校验过的名字）。
    public var needsResolution: Bool {
        selected == nil && TextNormalize.blankToNil(query) != nil
    }

    public func queryChanged() {
        searchTask?.cancel()
        // 改了字就不再算「已选中」——否则显示的名字与实际存的值会对不上
        if let selected, query != CitySearch.storedValue(for: selected) {
            self.selected = nil
        }
        guard CitySearch.isWorthSearching(query) else {
            matches = []
            message = ""
            return
        }
        let text = query
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: self?.debounce ?? .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.search(text)
        }
    }

    public func search(_ text: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            let found = try await provider.searchCities(name: text)
            guard !Task.isCancelled else { return }
            matches = found
            message = found.isEmpty ? CitySearch.noMatchMessage : ""
        } catch {
            guard !Task.isCancelled else { return }
            matches = []
            // 查不动 ≠ 没这个城市——两句话不得混（用户会以为自己拼错了）
            message = CitySearch.searchFailedMessage
            AppLog.error("city search failed \(AppLog.errRef(error))", .app)
        }
    }

    public func select(_ match: CityMatch) {
        selected = match
        query = CitySearch.storedValue(for: match)
        matches = []
        message = ""
    }

    /// 载入既有值（编辑既有衣柜时）。
    public func preload(_ city: String?) {
        query = city ?? ""
        selected = nil
        matches = []
    }
}

/// 带候选列表的城市输入框。
public struct CityPickerField: View {
    @Bindable var vm: CityPickerViewModel
    var title: String = "Home city"

    public init(vm: CityPickerViewModel, title: String = "Home city") {
        self.vm = vm
        self.title = title
    }

    public var body: some View {
        Group {
            TextField(title, text: $vm.query)
                .textContentType(.addressCity)
                .autocorrectionDisabled()
                .onChange(of: vm.query) { _, _ in vm.queryChanged() }
            if vm.isSearching {
                Text("Searching…").font(.caption2).foregroundStyle(DS.muted)
            }
            ForEach(vm.matches) { match in
                Button { vm.select(match) } label: {
                    // 标准名让同名城市分得开（Springfield 问题）
                    Text(match.displayName)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            if !vm.message.isEmpty {
                Text(vm.message).font(.caption2).foregroundStyle(.orange)
                    .accessibilityLabel(vm.message)
            } else if vm.needsResolution, vm.matches.isEmpty, !vm.isSearching {
                Text(CitySearch.unresolvedHint)
                    .font(.caption2).foregroundStyle(DS.muted)
            }
        }
    }
}
