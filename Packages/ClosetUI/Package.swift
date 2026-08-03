// swift-tools-version: 6.2
// ClosetUI — SwiftUI copilot UI 层。ViewModel 可 swift test 验证；View 用 swift build 验证编译。
// 渲染/交互需 iOS 模拟器（真机 App target 在 Xcode 组装，见 app-shell/）。
import PackageDescription

let package = Package(
    name: "ClosetUI",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "ClosetUI", targets: ["ClosetUI"])],
    dependencies: [
        .package(path: "../ClosetModel"), .package(path: "../ClosetCore"),
        .package(path: "../ClosetIntake"),
    ],
    targets: [
        .target(
            name: "ClosetUI",
            dependencies: [
                .product(name: "ClosetModel", package: "ClosetModel"),
                .product(name: "ClosetCore", package: "ClosetCore"),
                .product(name: "ClosetIntake", package: "ClosetIntake"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "ClosetUITests", dependencies: ["ClosetUI"]),
    ]
)
