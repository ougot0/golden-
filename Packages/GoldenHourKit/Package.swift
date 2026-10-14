// swift-tools-version:5.9
//
// GoldenHourKit — platform-independent logic for the GoldenHour app.
//
// - SolarEngine:    offline solar position and light-phase calculations (Foundation only).
// - GoldenHourCore: app logic that does not depend on UIKit/SwiftUI/CoreLocation
//                   (notification planning, coordinate parsing, compass math, formatting).
//
// Both modules build and test on macOS, iOS and Linux, so the numerical core can be
// verified in CI without a simulator.

import PackageDescription

let package = Package(
    name: "GoldenHourKit",
    defaultLocalization: "fr",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SolarEngine", targets: ["SolarEngine"]),
        .library(name: "GoldenHourCore", targets: ["GoldenHourCore"]),
    ],
    targets: [
        .target(name: "SolarEngine"),
        .target(name: "GoldenHourCore", dependencies: ["SolarEngine"]),
        .testTarget(
            name: "SolarEngineTests",
            dependencies: ["SolarEngine"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "GoldenHourCoreTests", dependencies: ["GoldenHourCore", "SolarEngine"]),
    ]
)
