// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "nanohat-oled",
    products: [
        .library(
            name: "nanohat-oled",
            targets: ["nanohat-oled"]),
    ],
    dependencies: [
        .package(url: "https://github.com/novi/i2c-swift.git", from: "0.1.2"),
    ],
    targets: [
        .target(
            name: "nanohat-oled",
            dependencies: ["I2C"]),
    ]
)
