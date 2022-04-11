// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Sahha",
    platforms: [
             .iOS(.v12),
         ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Sahha",
            targets: ["Sahha"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/microsoft/appcenter-sdk-apple.git", from: "4.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Sahha",
            dependencies: [
                .product(name: "AppCenterAnalytics", package: "appcenter-sdk-apple"),.product(name: "AppCenterCrashes", package: "appcenter-sdk-apple")]),
        .testTarget(
            name: "SahhaTests",
            dependencies: ["Sahha"]),
    ],
    swiftLanguageVersions: [.v5]
)
