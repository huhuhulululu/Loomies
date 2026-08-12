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
    public static let hint = "Used to filter by weather. Leave unset if unsure."

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
                                        paletteID == entry.id ? DS.accent : Color.white.opacity(0.25),
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

    public static let hint = "Cut details we use to flatter your body shape."

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
                            .frame(height: 32)
                            .background(isOn ? DS.accent.opacity(0.22) : Color.white.opacity(0.06))
                            .foregroundStyle(isOn ? DS.accent : DS.ink)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(
                                    isOn ? DS.accent : Color.white.opacity(0.12),
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
                                .frame(height: 32)
                                .background(isOn ? DS.accent.opacity(0.22) : Color.white.opacity(0.06))
                                .foregroundStyle(isOn ? DS.accent : DS.ink)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().strokeBorder(
                                        isOn ? DS.accent : Color.white.opacity(0.12),
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
