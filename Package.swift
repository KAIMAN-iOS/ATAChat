// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ATAChat",
    defaultLocalization: "en",
    platforms: [.iOS("13.0")],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ATAChat",
            targets: ["ATAChat"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
//         .package(url: "https://github.com/kirualex/KAPinField", from: "5.0.1")
        .package(name: "Firebase",
                   url: "https://github.com/firebase/firebase-ios-sdk.git",
//                   .branch("6.34-spm-beta")),
                   from: "7.6.0"),
        
        .package(url: "https://github.com/jerometonnelier/KCoordinatorKit", .branch("master")),
        .package(url: "https://github.com/jerometonnelier/KExtensions", .branch("master")),
        .package(url: "https://github.com/jerometonnelier/ActionButton", .branch("master")),
        .package(url: "https://github.com/jerometonnelier/ATAConfiguration", .branch("master")),
        .package(url: "https://github.com/MessageKit/MessageKit", from: "3.5.0"),
        .package(url: "https://github.com/malcommac/SwiftDate", from: "6.3.1"),
        .package(url: "https://github.com/Minitour/EasyNotificationBadge", from: "1.2.5"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ATAChat",
            dependencies: [.product(name: "FirebaseAuth", package: "Firebase"),
                           .product(name: "FirebaseAnalytics", package: "Firebase"),
                           .product(name: "FirebaseFirestore", package: "Firebase"),
                           .product(name: "FirebaseStorage", package: "Firebase"),
                           .product(name: "FirebaseDatabase", package: "Firebase"),
                           .product(name: "FirebaseMessaging", package: "Firebase"),
                           "KCoordinatorKit",
                           "ActionButton",
                           "ATAConfiguration",
                           "MessageKit",
                           "SwiftDate",
                           "EasyNotificationBadge"])
    ]
)
