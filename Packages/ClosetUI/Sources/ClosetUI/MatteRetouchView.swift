import SwiftUI
import ClosetModel
import ClosetCore

/// 抠图边缘手修编辑器（D96，缺口 #10）。DESIGN §F1 标「竞品被骂点必须做」。
///
/// 状态只有一串笔画：撤销＝丢掉最后一笔重渲染，不维护像素级历史，
/// 反复涂抹也不累积编码损失（真相在 `MatteRetouch`）。
@MainActor
@Observable
public final class MatteRetouchViewModel {
    /// 自动抠图结果（编辑基底）
    public let matted: Data
    /// 原图；没有就只能擦不能找回——按钮据此禁用并说明，不让人点了没反应
    public let original: Data?

    public private(set) var strokes: [MatteRetouch.Stroke] = []
    public var mode: MatteRetouch.Mode = .erase
    /// 归一化半径（相对画布长边）
    public var radius: CGFloat = 0.04
    public private(set) var message: String = ""

    public init(matted: Data, original: Data?) {
        self.matted = matted
        self.original = original
    }

    public var canRestore: Bool { MatteRetouch.canRestore(original: original) }
    public var canUndo: Bool { !strokes.isEmpty }
    public var hasEdits: Bool { !strokes.isEmpty }

    public static let title = "Fix edges"
    public static let eraseTitle = "Erase"
    public static let restoreTitle = "Bring back"
    public static let undoTitle = "Undo"
    public static let brushTitle = "Brush size"
    public static let hint =
        "Erase leftover background, or bring back a corner the cutout ate."

    /// 当前预览。无笔画时就是原始抠图结果（不做无谓重编码）。
    public var preview: Data {
        MatteRetouch.apply(strokes, to: matted, original: original) ?? matted
    }

    public func begin(at point: CGPoint) {
        guard mode != .restore || canRestore else {
            message = MatteRetouch.restoreUnavailableMessage
            return
        }
        message = ""
        strokes.append(MatteRetouch.Stroke(mode: mode, radius: radius, points: [point]))
    }

    public func extend(to point: CGPoint) {
        guard var last = strokes.popLast() else { return }
        last = MatteRetouch.Stroke(
            mode: last.mode, radius: last.radius, points: last.points + [point])
        strokes.append(last)
    }

    public func undo() {
        guard canUndo else { return }
        strokes.removeLast()
        message = ""
    }

    /// 提交结果；无改动返回 nil（调用方按「没改」处理，不重写文件）。
    public func commit() -> Data? {
        MatteRetouch.apply(strokes, to: matted, original: original)
    }
}

#if canImport(UIKit)
import UIKit

/// 画布 + 笔刷。手势坐标按显示尺寸归一化，应用时落到全分辨率——两边一致。
public struct MatteRetouchView: View {
    @State private var vm: MatteRetouchViewModel
    @Environment(\.dismiss) private var dismiss
    let onCommit: (Data) -> Void

    public init(matted: Data, original: Data?, onCommit: @escaping (Data) -> Void) {
        _vm = State(initialValue: MatteRetouchViewModel(matted: matted, original: original))
        self.onCommit = onCommit
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                canvas
                controls
            }
            .padding(16)
            .navigationTitle(MatteRetouchViewModel.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // 无改动就不重写文件（避免每次打开都掉一点质量）
                        if let data = vm.commit() { onCommit(data) }
                        dismiss()
                    }
                    .disabled(!vm.hasEdits)
                }
            }
        }
    }

    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                // 棋盘底：透明区域必须看得出来是透明，不是白衣服
                CheckerboardBackground()
                if let ui = UIImage(data: vm.preview) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let p = normalize(value.location, in: geo.size)
                        if value.translation == .zero { vm.begin(at: p) }
                        else { vm.extend(to: p) }
                    })
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Mode", selection: $vm.mode) {
                Text(MatteRetouchViewModel.eraseTitle).tag(MatteRetouch.Mode.erase)
                Text(MatteRetouchViewModel.restoreTitle).tag(MatteRetouch.Mode.restore)
            }
            .pickerStyle(.segmented)
            HStack {
                Text(MatteRetouchViewModel.brushTitle)
                    .font(.caption).foregroundStyle(DS.muted)
                Slider(value: $vm.radius, in: 0.01...0.15)
                    .accessibilityLabel(MatteRetouchViewModel.brushTitle)
                Button(MatteRetouchViewModel.undoTitle) { vm.undo() }
                    .disabled(!vm.canUndo)
            }
            if !vm.message.isEmpty {
                Text(vm.message).font(.caption).foregroundStyle(.orange)
                    .accessibilityLabel(vm.message)
            }
            Text(MatteRetouchViewModel.hint)
                .font(.caption2).foregroundStyle(DS.muted)
        }
    }

    private func normalize(_ point: CGPoint, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGPoint(x: point.x / size.width, y: point.y / size.height)
    }
}

/// 透明区域的棋盘底——不然抠掉的地方看着像白衣服。
struct CheckerboardBackground: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 12
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color.white.opacity(0.10)))
            var row = 0
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = (row % 2 == 0) ? 0 : step
                while x < size.width {
                    context.fill(
                        Path(CGRect(x: x, y: y, width: step, height: step)),
                        with: .color(Color.white.opacity(0.06)))
                    x += step * 2
                }
                y += step
                row += 1
            }
        }
        .allowsHitTesting(false)
    }
}
#endif
