// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(name: "NetCore",
                      platforms: [ .iOS(.v14),
                                   .macOS(.v11) ],
                      products: [
                        .library(name: "NetCore", targets: ["NetCore"]),
                      ],
                      targets: [
                        .target(name: "NetCore"),
                        .testTarget(
                            name: "NetCoreTests",
                            dependencies: ["NetCore"]),
                      ])
