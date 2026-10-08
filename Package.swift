// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeskTidy",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "DeskTidy",
            dependencies: [
                "DeskTidyCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ]
        ),
        // 不依赖界面，Linux 上也能编译和测试
        .target(name: "DeskTidyCore"),
        .testTarget(
            name: "DeskTidyCoreTests",
            dependencies: ["DeskTidyCore"]
        )
    ]
)
