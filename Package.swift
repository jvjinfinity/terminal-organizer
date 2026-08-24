// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TerminalOrganizer",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "TerminalOrganizer", targets: ["TerminalOrganizer"]),
        .executable(name: "to-notify", targets: ["to-notify"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", revision: "cb3c863a3fa62ec2bf04cadf432937589f66b43e"),
    ],
    targets: [
        .target(
            name: "CWDProbe",
            path: "Sources/CWDProbe",
            publicHeadersPath: "include"
        ),
        .target(
            name: "TOSupport",
            path: "Sources/TOSupport"
        ),
        .executableTarget(
            name: "to-notify",
            dependencies: ["TOSupport"],
            path: "Sources/to-notify"
        ),
        .executableTarget(
            name: "TerminalOrganizer",
            dependencies: [
                "CWDProbe",
                "TOSupport",
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            path: "Sources/TerminalOrganizer"
        ),
    ]
)
