// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Partly",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Partly", targets: ["Partly"]),
        .executable(name: "Check", targets: ["Check"])
    ],
    targets: [
        .target(
            name: "PartlyCore",
            resources: [
                .copy("AppIcon.png"),
            ],
            exclude: ["LogoLockup.png"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "Partly",
            dependencies: ["PartlyCore"]
        ),
        .executableTarget(
            name: "Check",
            dependencies: ["PartlyCore"]
        ),
    ]
)
