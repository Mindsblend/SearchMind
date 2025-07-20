// swift-tools-version: 5.5
import PackageDescription

let package = Package(
    name: "SearchMind",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "SearchMind",
            targets: ["SearchMind"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),
    ],
    targets: [
        .target(
            name: "SearchMind",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
            ]
            // No resources here — your Firebase plist is for tests only
        ),
        .testTarget(
            name: "SearchMindTests",
            dependencies: ["SearchMind"],
            resources: [
                .process("Resources/GoogleService-Info.plist"), // 🔥 Put the file here
            ]
        ),
    ]
)
