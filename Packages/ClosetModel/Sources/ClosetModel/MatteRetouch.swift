import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import ClosetCore

/// 抠图边缘手修（D96，缺口 #10）。DESIGN §F1 标「**竞品被骂点必须做**」——
/// 自动抠图总有啃掉袖口、或留下一角背景的时候，没有手修就只能重拍。
///
/// 状态就是**一串笔画**，渲染永远从「原图 + 自动抠图结果」重算：
/// 撤销＝丢掉最后一笔（不需要像素级历史），反复涂抹也不会累积编码损失。
public enum MatteRetouch {

    public enum Mode: String, Sendable, Equatable {
        /// 擦掉（抠多了背景没除净）→ alpha 归零
        case erase
        /// 找回（抠没了衣服的一角）→ 从**原图**取回像素，不凭空造
        case restore
    }

    /// 一笔。坐标与半径都是**归一化**的（0…1，相对画布长边），
    /// 这样在缩略图上画、在全分辨率上应用，结果一致。
    public struct Stroke: Sendable, Equatable {
        public let mode: Mode
        public let radius: CGFloat
        public let points: [CGPoint]
        public init(mode: Mode, radius: CGFloat, points: [CGPoint]) {
            self.mode = mode
            self.radius = radius
            self.points = points
        }
    }

    /// 没有原图就无法「找回」——必须说清楚，不能让按钮点了没反应。
    public static func canRestore(original: Data?) -> Bool { original != nil }
    public static let restoreUnavailableMessage =
        "Restore needs the original photo, which isn't stored for this piece. You can still erase."

    /// 应用笔画。`nil` = 没有可应用的改动 / 输入坏了（不产出假图冒充修好了）。
    /// 画布尺寸取**抠图结果**的（原图分辨率不同也不拉伸变形）。
    public static func apply(_ strokes: [Stroke], to matted: Data, original: Data?) -> Data? {
        let usable = strokes.filter { !$0.points.isEmpty && $0.radius > 0 }
        guard !usable.isEmpty else { return nil }
        guard let matteImage = decode(matted) else { return nil }
        let width = matteImage.width, height = matteImage.height
        guard width > 0, height > 0 else { return nil }

        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let full = CGRect(x: 0, y: 0, width: width, height: height)
        ctx.draw(matteImage, in: full)

        // 长边定尺：半径在长短边上是同一物理大小（否则细长图上笔刷会被压扁）
        let longSide = CGFloat(max(width, height))

        // 先擦：destinationOut 把画过的地方 alpha 抹掉
        ctx.saveGState()
        ctx.setBlendMode(.destinationOut)
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        for stroke in usable where stroke.mode == .erase {
            paint(stroke, in: ctx, width: width, height: height, longSide: longSide)
        }
        ctx.restoreGState()

        // 再找回：把原图裁进笔画形状（`clip` 到笔画路径后画原图）
        if let original, let originalImage = decode(original) {
            let restores = usable.filter { $0.mode == .restore }
            if !restores.isEmpty {
                ctx.saveGState()
                let path = CGMutablePath()
                for stroke in restores {
                    appendPath(stroke, to: path, width: width, height: height, longSide: longSide)
                }
                ctx.addPath(path)
                ctx.clip()
                ctx.draw(originalImage, in: full)   // 尺寸不同时按画布铺满，不另开一套坐标
                ctx.restoreGState()
            }
        }

        guard let out = ctx.makeImage() else { return nil }
        return encodePNG(out)
    }

    // MARK: - 像素读取（测试与 UI 预览用）

    /// 归一化坐标处的 alpha（0…1）；越界或坏数据返回 nil。
    public static func alphaSample(_ data: Data, normalizedX: Double, normalizedY: Double) -> Double? {
        guard normalizedX >= 0, normalizedX <= 1, normalizedY >= 0, normalizedY <= 1,
              let image = decode(data) else { return nil }
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return nil }
        var pixel: [UInt8] = [0, 0, 0, 0]
        guard let ctx = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let x = min(w - 1, max(0, Int(normalizedX * Double(w))))
        // CGContext 原点在左下，UI/测试坐标原点在左上 → y 翻转
        let y = min(h - 1, max(0, Int((1 - normalizedY) * Double(h))))
        ctx.draw(image, in: CGRect(x: -x, y: -y, width: w, height: h))
        return Double(pixel[3]) / 255.0
    }

    public static func encodePNG(_ image: CGImage) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out as CFMutableData, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    // MARK: - Private

    private static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// 归一化点 → 画布坐标（y 翻转：CGContext 原点在左下）。
    private static func canvasPoint(
        _ p: CGPoint, width: Int, height: Int
    ) -> CGPoint {
        CGPoint(x: p.x * CGFloat(width), y: (1 - p.y) * CGFloat(height))
    }

    private static func appendPath(
        _ stroke: Stroke, to path: CGMutablePath, width: Int, height: Int, longSide: CGFloat
    ) {
        let r = max(1, stroke.radius * longSide)
        let pts = stroke.points.map { canvasPoint($0, width: width, height: height) }
        guard let first = pts.first else { return }
        if pts.count == 1 {
            path.addEllipse(in: CGRect(
                x: first.x - r, y: first.y - r, width: r * 2, height: r * 2))
            return
        }
        // 连续拖动是采样点序列——必须连成线段，否则画出一串断开的圆点
        let line = CGMutablePath()
        line.move(to: first)
        for p in pts.dropFirst() { line.addLine(to: p) }
        let stroked = line.copy(strokingWithWidth: r * 2, lineCap: .round,
                                lineJoin: .round, miterLimit: 1)
        path.addPath(stroked)
    }

    private static func paint(
        _ stroke: Stroke, in ctx: CGContext, width: Int, height: Int, longSide: CGFloat
    ) {
        let path = CGMutablePath()
        appendPath(stroke, to: path, width: width, height: height, longSide: longSide)
        ctx.addPath(path)
        ctx.fillPath()
    }
}
