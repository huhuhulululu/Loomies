import SwiftUI
import ClosetCore

/// 属性录入控件（D83）：温区 / 颜色 / 风格属性——三者是推荐引擎的输入，
/// 此前无录入面导致天气门、配色打分、体型加权在真实数据上空转。
/// 温区 / 颜色三处复用：单品详情、手动新增（AddPieceSheet）、入库确认；
/// 风格属性（Cut details）只在详情页——新增时问剪裁细节太重，详情页补录即可。

extension GarmentColorPalette.Entry {
    /// 色板 → SwiftUI 颜色（Core 侧只存 0…1 分量，保持零 SwiftUI 依赖）。
    public var swatchColor: Color { Color(red: red, green: green, blue: blue) }
}

/// 温区选择器：5 档 + 「Unknown」（未知不硬过滤，不替用户假设）。
public struct WarmthPicker: View {
    @Binding var warmthRaw: Int?
    public init(warmthRaw: Binding<Int?>) { _warmthRaw = warmthRaw }

    public static let unknownTitle = "Not set"
    /// D148：原文是「Used to filter by weather. Leave unset if unsure.」——
    /// 它主动**邀请**用户留空，却只字不提留空的后果：温区未标时天气门整条跳过
    ///（`CandidateFilter` gate #1），那件**永远不会**因为天气被筛掉。
    /// 于是厚羽绒服留成「Not set」，85°F 那天照样被推出来，
    /// 用户看到的是「这 App 不懂天气」，而真相是「你没告诉它这件多厚」。
    /// 场合那条早就把话说全了（「Leave all off if it works for anything」）——
    /// 同一个文件里两条同类提示，一条说了一条没说。
    public static let hint =
        "Used to filter by weather. Not sure? Leave it unset — "
        + "that piece is then never ruled out on hot or cold days."

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Warmth", selection: $warmthRaw) {
                Text(Self.unknownTitle).tag(Optional<Int>.none)
                ForEach(Warmth.ordered, id: \.rawValue) { w in
                    Text(w.displayTitle).tag(Optional(w.rawValue))
                }
            }
            .accessibilityLabel("Warmth")
            if let raw = warmthRaw, let w = Warmth(rawValue: raw) {
                Text(w.entryHint).font(.caption2).foregroundStyle(DS.muted)
            } else {
                Text(Self.hint).font(.caption2).foregroundStyle(DS.muted)
            }
        }
    }
}

/// 颜色选择器：色板色块横排，选中描边；再点取消（回到未知）。
public struct ColorSwatchPicker: View {
    @Binding var paletteID: String?
    public init(paletteID: Binding<String?>) { _paletteID = paletteID }

    public static let hint = "Used for color-harmony scoring. Tap again to clear."

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(GarmentColorPalette.entries) { entry in
                        Button {
                            paletteID = (paletteID == entry.id) ? nil : entry.id
                        } label: {
                            Circle()
                                .fill(entry.swatchColor)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().strokeBorder(
                                        paletteID == entry.id ? DS.accent : DS.hairline,
                                        lineWidth: paletteID == entry.id ? 3 : 1))
                                // 44pt 命中区（a11y 下限），视觉仍是 30pt 色点
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(entry.title)
                        .accessibilityAddTraits(paletteID == entry.id ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, 2)
            }
            Text(selectionCaption).font(.caption2).foregroundStyle(DS.muted)
        }
    }

    private var selectionCaption: String {
        guard let e = GarmentColorPalette.entry(id: paletteID) else { return Self.hint }
        return e.isNeutral ? "\(e.title) · neutral (goes with everything)" : e.title
    }
}

/// 风格属性多选：分区 chips（体型加权输入）。
public struct StyleAttributePicker: View {
    @Binding var attributes: Set<StyleAttribute>
    public init(attributes: Binding<Set<StyleAttribute>>) { _attributes = attributes }

    public static let hint = "Cut details — we use these to match pieces to your proportions."

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(StyleAttribute.entryGroups, id: \.title) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.muted)
                    FlowChips(
                        attributes: group.attributes,
                        selected: attributes,
                        toggle: { attr in
                            if attributes.contains(attr) { attributes.remove(attr) }
                            else { attributes.insert(attr) }
                        })
                }
            }
            Text(Self.hint).font(.caption2).foregroundStyle(DS.muted)
        }
    }
}

/// 横向滚动 chip 组（非换行——大字号下靠滚动而非折行）（避免引入布局依赖；数量有限，横向滚动即可）。
struct FlowChips: View {
    let attributes: [StyleAttribute]
    let selected: Set<StyleAttribute>
    let toggle: (StyleAttribute) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attributes, id: \.rawValue) { attr in
                    let isOn = selected.contains(attr)
                    Button { toggle(attr) } label: {
                        Text(attr.displayTitle)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .frame(minHeight: DS.chipMinHeight)
                            .background(isOn ? DS.accent.opacity(0.22) : DS.surface)
                            .foregroundStyle(isOn ? DS.accent : DS.ink)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(
                                    isOn ? DS.accent : DS.hairline,
                                    lineWidth: isOn ? 1.5 : 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(attr.displayTitle)
                    .accessibilityAddTraits(isOn ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 2)
        }
    }
}


/// 护理符号多选（D93）。视觉语言与 `FlowChips` 一致（后者是 StyleAttribute 专用，
/// 不去为复用而改动它——外科手术）；命中区 44pt。
public struct CareSymbolPicker: View {
    @Binding var selection: Set<CareSymbol>
    public init(selection: Binding<Set<CareSymbol>>) { _selection = selection }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CareSymbol.allCases, id: \.rawValue) { symbol in
                        let isOn = selection.contains(symbol)
                        Button {
                            if isOn { selection.remove(symbol) } else { selection.insert(symbol) }
                        } label: {
                            Text(symbol.displayTitle)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .frame(minHeight: DS.chipMinHeight)
                                .background(isOn ? DS.accent.opacity(0.22) : DS.surface)
                                .foregroundStyle(isOn ? DS.accent : DS.ink)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().strokeBorder(
                                        isOn ? DS.accent : DS.hairline,
                                        lineWidth: 1))
                                .frame(minHeight: 44)          // 命中区，不是视觉高度
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
            Text(CareSymbol.entryHint).font(.caption2).foregroundStyle(DS.muted)
        }
    }
}

/// 场合多选（D108）。场合是 `CandidateFilter` 的**硬过滤**输入，引擎只认固定几个值；
/// 此前详情页是逗号分隔的自由文本——打错一个字母，这件衣服就永远不再被推荐，
/// 而用户看不到任何异样。
///
/// 存量的自定义值原样列出并可取消，**不静默删掉用户的数据**。
// D115：这些 chip 此前用 `Color.white.opacity(0.06/0.12)` 做底与描边——
// 那是照深色底写的，而 app 当时只有**浅色**：暖骨白上叠 6% 白等于什么都没有。
// 全 app 用得最多的控件因此没有可见边界（「拼装感」的直接来源）。
// 改用语义 token，两套配色下都成立。
public struct OccasionChips: View {
    @Binding var selection: Set<String>
    let custom: [String]

    public init(selection: Binding<Set<String>>, custom: [String] = []) {
        _selection = selection
        self.custom = custom
    }

    public static let hint =
        "Used to filter what gets suggested. Leave all off if it works for anything."

    private var values: [String] { OccasionMix.choices + custom }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        let isOn = selection.contains(value)
                        Button {
                            if isOn { selection.remove(value) } else { selection.insert(value) }
                        } label: {
                            Text(OccasionMix.displayTitle(value))
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .frame(minHeight: DS.chipMinHeight)
                                .background(isOn ? DS.accent.opacity(0.22) : DS.surface)
                                .foregroundStyle(isOn ? DS.accent : DS.ink)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().strokeBorder(
                                        isOn ? DS.accent : DS.hairline, lineWidth: 1))
                                .frame(minHeight: 44)   // 命中区，不是视觉高度
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
            Text(Self.hint).font(.caption2).foregroundStyle(DS.muted)
        }
    }
}

/// 输入辅助修饰符（D108）。`keyboardType` / `textInputAutocapitalization` 是
/// iOS 专属 API——直接写在共享 View 里 macOS 编不过（而 `swift test` 跑在 macOS，
/// 这类问题只有 xcodebuild 才报，见 CLAUDE.md 的验证条款）。
extension View {
    /// 数值字段用小数键盘：此前尺寸框弹的是默认字母键盘。
    @ViewBuilder
    func decimalKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    /// 名称/品牌：按词首大写（不是句首）。
    @ViewBuilder
    func wordsCapitalized() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.words)
        #else
        self
        #endif
    }

    /// 尺码：全大写（M / XL / 8），且不该被自动纠正。
    @ViewBuilder
    func charactersCapitalized() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.characters)
        #else
        self
        #endif
    }
}
