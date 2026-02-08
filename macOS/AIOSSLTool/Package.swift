// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AIOSSLTool",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "AIOSSLTool",
            targets: ["AIOSSLTool"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AIOSSLTool",
            dependencies: [],
            path: ".",
            exclude: [
                "Info.plist",
                "AIOSSLTool.entitlements",
                "build.sh",
                "AIO SSL Tool.app",
                "AIOSSLTool.dmg",
                "AppIcon.icns",
                "icon-source.png"
            ],
            sources: [
                "AIOSSLToolApp.swift",
                "ContentView.swift",
                "ViewModels/SSLToolViewModel.swift",
                "Models/CSRDetails.swift",
                "Views/ChainBuilderView.swift",
                "Views/CSRGenerationView.swift",
                "Views/ExtractPFXView.swift",
                "Views/SettingsView.swift",
                "Utils/CertificateUtils.swift"
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
