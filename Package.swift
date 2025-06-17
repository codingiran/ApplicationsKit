// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ApplicationsKit",
    platforms: [
        .macOS(.v10_15),
        .macCatalyst(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ApplicationsKit",
            targets: ["ApplicationsKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/codingiran/SwiftyCache.git", from: "1.0.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ApplicationsKit",
            dependencies: [
                "SwiftyCache",
            ],
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "ApplicationsKitTests",
            dependencies: ["ApplicationsKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
