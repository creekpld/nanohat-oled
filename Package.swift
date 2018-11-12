// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "NanoHatOLED",
    products: [
        .library(
            name: "NanoHatOLED",
            targets: ["NanoHatOLED"]),
    ],
    dependencies: [
        .package(url: "https://github.com/novi/i2c-swift.git", from: "0.1.2"),
    ],
    targets: [
        .target(
            name: "NanoHatOLED",
            dependencies: ["I2C"]),
    ]
)
