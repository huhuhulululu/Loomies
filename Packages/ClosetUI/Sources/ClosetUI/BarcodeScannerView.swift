import SwiftUI

#if os(iOS)
import VisionKit
import Vision

/// 相机条码扫描（A5 / HANDOFF §6.5）：VisionKit `DataScannerViewController` 的
/// SwiftUI 包装，**只认条码**（EAN/UPC，零售商品码）。
///
/// 契约 C3：扫到的**原始字符串原样交回调用方**——本视图不查任何东西。
/// 调用方负责 `OpenProductFactsClient.normalizeBarcode` → `IntakeViewModel
/// .enrichFromPublicBarcode`，与手输走**同一条**通路（不新开第二条 lookup，
/// 也就不会绕过 `PublicAPITransport` 出网对账）。
///
/// D92：整文件在 `#if os(iOS)` 内——VisionKit/UIKit 只在真机/模拟器有；
/// macOS 的 `swift test` 编不到这里，所以可用性判定的**桌面回退**（恒 false）
/// 落在下面 `isAvailable` 的 `#else`（在 `PhotoCaptureViews` 侧），本类型
/// 在 macOS 上直接不存在。
public struct BarcodeScannerView: UIViewControllerRepresentable {
    /// 扫到的**原始** payload（未归一）。调用方 normalize + enrich。
    private let onScanned: (String) -> Void

    public init(onScanned: @escaping (String) -> Void) {
        self.onScanned = onScanned
    }

    /// 相机条码扫描此刻是否可用：设备支持 DataScanner（A12+ 神经引擎）**且**
    /// 相机可用（已授权、未被家长控制限制）。模拟器无摄像头 → `isSupported`
    /// 即为 false，天然降级手输。
    ///
    /// `@MainActor`：`DataScannerViewController` 的可用性是主线程状态；调用方
    /// （SwiftUI View）本就在主线程，标注让严格并发下的 xcodebuild 也干净。
    @MainActor public static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    public func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    public func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        // 扫中一次即停（一次性）：SwiftUI 可能在 stop 后再次 update，别把相机重启。
        // 首次 update 时视图可能尚未入窗，startScanning 会抛 → try? 吞掉，
        // 下一次 update（viewDidAppear 之后）再成功启动。
        guard !context.coordinator.isFinished else { return }
        try? scanner.startScanning()
    }

    public static func dismantleUIViewController(
        _ scanner: DataScannerViewController, coordinator: Coordinator
    ) {
        scanner.stopScanning()
    }

    public func makeCoordinator() -> Coordinator { Coordinator(onScanned: onScanned) }

    /// `@MainActor`：`DataScannerViewControllerDelegate` 的回调本就在主线程投递，
    /// 且我们在回调里读写 `isFinished`、调 `stopScanning()`——标注让严格并发下
    /// 满足 delegate 的 `@MainActor` 要求，不产生 Sendable 噪声（D92）。
    @MainActor
    public final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScanned: (String) -> Void
        /// 一次性闸门：认第一个有 payload 的条码，之后不再回调（也不重启扫描）。
        private(set) var isFinished = false

        init(onScanned: @escaping (String) -> Void) { self.onScanned = onScanned }

        public func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            emitFirstBarcode(from: addedItems, scanner: dataScanner)
        }

        /// 用户轻点某个高亮条码也算确认（未自动锁定时的兜底）。
        public func dataScanner(
            _ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem
        ) {
            emitFirstBarcode(from: [item], scanner: dataScanner)
        }

        private func emitFirstBarcode(
            from items: [RecognizedItem], scanner: DataScannerViewController
        ) {
            guard !isFinished else { return }
            for case let .barcode(barcode) in items {
                guard let payload = barcode.payloadStringValue, !payload.isEmpty else { continue }
                isFinished = true
                scanner.stopScanning()
                onScanned(payload)   // 原始字符串交回；归一 + 查询在调用方
                return
            }
        }
    }
}
#endif
