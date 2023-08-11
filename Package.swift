// swift-tools-version:5.5
import PackageDescription

let package = Package(
        name: "TronKit",
        platforms: [
          .iOS(.v13),
        ],
        products: [
          .library(
                  name: "TronKit",
                  targets: ["TronKit"]
          ),
        ],
        dependencies: [
          
          .package(url: "https://github.com/Kitura/BlueSocket.git", .upToNextMajor(from: "2.0.0")),
          .package(url: "https://github.com/tristanhimmelman/ObjectMapper.git", .upToNextMajor(from: "4.1.0")),
          .package(url: "https://github.com/horizontalsystems/HsToolKit.Swift.git", .upToNextMajor(from: "2.0.0")),
          .package(url: "https://github.com/horizontalsystems/HsExtensions.Swift.git", .upToNextMajor(from: "1.0.6")),
        ],
        targets: [
          .target(
                  name: "TronKit",
                  dependencies: [
                    .product(name: "Socket", package: "BlueSocket"),
                    .product(name: "HsToolKit", package: "HsToolKit.Swift"),
                    .product(name: "HsExtensions", package: "HsExtensions.Swift"),
                  ]
          )
        ]
)
