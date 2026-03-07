// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "OllamaService",
  platforms: [
    .macOS(.v15),
    .iOS(.v18)
  ],
  products: [
    .library(
      name: "OllamaService",
      targets: ["OllamaService"]
    )
  ],
  targets: [
    .target(
      name: "OllamaService"
    ),
    .testTarget(
      name: "OllamaServiceTests",
      dependencies: ["OllamaService"]
    )
  ]
)
