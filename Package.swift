// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeskTidy",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "DeskTidy",
            dependencies: [
                "DeskTidyCore",
                "KeyboardShortcuts"
            ]
        ),
        // 不依赖界面，Linux 上也能编译和测试
        .target(name: "DeskTidyCore"),
        // sindresorhus/KeyboardShortcuts 2.3.0（MIT），放进项目里是为了改资源包的查找位置，
        // 否则签名后的 .app 找不到它的翻译文字。见 Vendor/KeyboardShortcuts/README.md
        .target(
            name: "KeyboardShortcuts",
            path: "Vendor/KeyboardShortcuts/Sources/KeyboardShortcuts"
        ),
        .testTarget(
            name: "DeskTidyCoreTests",
            dependencies: ["DeskTidyCore"]
        )
    ]
)
