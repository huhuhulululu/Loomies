import SwiftUI
#if canImport(UIKit)
import UIKit

/// UIKit 分享面板（MP4 / 图片）。
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
/// macOS 占位：直接空视图（分享在 iOS 主路径）。
struct ShareSheet: View {
    var items: [Any]
    var body: some View {
        Text("Share is available on iOS")
            .padding()
    }
}
#endif
