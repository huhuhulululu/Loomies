// swift-tools-version: 6.0
// ClosetModel — SwiftData 实体层 + 级联/转移/不变量服务。
// 命令行 swift test 用内存 ModelContainer 验证（宿主 macOS）；真机 App 部署 iOS 26 + CloudKit 私有库。
import PackageDescription

let package = Package(
    name: "ClosetModel",
    platforms: [.iOS(.v17), .macOS(.v15)],
    products: [.library(name: "ClosetModel", targets: ["ClosetModel"])],
    targets: [
        .target(name: "ClosetModel"),
        .testTarget(name: "ClosetModelTests", dependencies: ["ClosetModel"]),
    ]
)
