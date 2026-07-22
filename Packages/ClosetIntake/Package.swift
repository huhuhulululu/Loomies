// swift-tools-version: 6.2
// ClosetIntake — F1 扫描入库（MVP-PLAN SI-0 capability seam）。
// 抠图/打标/OCR 抽象为协议：mock 可命令行测；真实 Vision 实现真机（RealServices，#if canImport(Vision)）。
import PackageDescription

let package = Package(
    name: "ClosetIntake",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "ClosetIntake", targets: ["ClosetIntake"])],
    dependencies: [.package(path: "../ClosetModel"), .package(path: "../ClosetCore")],
    targets: [
        .target(name: "ClosetIntake", dependencies: [
            .product(name: "ClosetModel", package: "ClosetModel"),
            .product(name: "ClosetCore", package: "ClosetCore"),
        ]),
        .testTarget(name: "ClosetIntakeTests", dependencies: ["ClosetIntake"]),
    ]
)
