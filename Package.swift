// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-imap",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "IMAP",
            targets: ["IMAP"]
        ),
        .library(
            name: "IMAP Network",
            targets: ["IMAP Network"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-3501.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-3501-coder.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "IMAP",
            dependencies: [
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "RFC 3501", package: "swift-rfc-3501"),
                .product(name: "RFC 3501 Coder", package: "swift-rfc-3501-coder"),
            ]
        ),
        .target(
            name: "IMAP Network",
            dependencies: [
                .target(name: "IMAP"),
                .product(name: "Byte", package: "swift-byte"),
            ]
        ),
        .testTarget(
            name: "IMAP Tests",
            dependencies: [
                .target(name: "IMAP"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "RFC 3501", package: "swift-rfc-3501"),
            ]
        ),
        .testTarget(
            name: "IMAP Network Tests",
            dependencies: [
                .target(name: "IMAP"),
                .target(name: "IMAP Network"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableExperimentalFeature("Lifetimes"),
        .treatAllWarnings(as: .error),
    ]
}
