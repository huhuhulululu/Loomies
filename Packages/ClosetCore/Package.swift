// swift-tools-version: 6.0
// ClosetCore — 纯 Swift 逻辑核心（无 iOS SDK 依赖，可命令行 swift test 验证）。
// 上层 iOS App（min iOS 26）以本地 SPM package 方式引用；本包本身对宿主 macOS 亦可编译测试。
import PackageDescription

let package = Package(
    name: "ClosetCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ClosetCore", targets: ["ClosetCore"]),
    ],
    targets: [
        .target(name: "ClosetCore"),
        .testTarget(name: "ClosetCoreTests", dependencies: ["ClosetCore"]),
    ]
)
