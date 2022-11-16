// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(name: "SSNetwork",
                      platforms: [ .iOS(.v13),
                                   .macOS(.v10_15)],
                      products: [
                        .library(name: "SSNetwork", targets: ["SSNetwork"]),
                      ],
                      targets: [
                        .target(name: "SSNetwork"),
                        .testTarget(
                            name: "SSNetworkTests",
                            dependencies: ["SSNetwork"]),
                      ])
