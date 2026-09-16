// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "shift-happens",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ShiftHappensCore", path: "Sources/ShiftHappensCore"),
        .executableTarget(
            name: "ShiftHappens",
            dependencies: ["ShiftHappensCore"],
            path: "Sources/ShiftHappens"
        ),
        .testTarget(
            name: "ShiftHappensTests",
            dependencies: ["ShiftHappensCore"],
            path: "Tests/ShiftHappensTests"
        )
    ]
)
