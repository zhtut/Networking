// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


var pDependencies = [PackageDescription.Package.Dependency]()
var cDependencies = [PackageDescription.Target.Dependency]()
var wDependencies = [PackageDescription.Target.Dependency]()

//#if os(Linux)
let latestVersion: Range<Version> = "0.0.1"..<"99.99.99"
pDependencies += [
    .package(url: "https://github.com/apple/swift-crypto.git", latestVersion),
    .package(url: "https://github.com/zhtut/CombineX.git", latestVersion),
]
cDependencies += [
    .product(name: "Crypto", package: "swift-crypto"),
]
wDependencies += [
    "CombineX"
]
//#endif


let package = Package(name: "Networking",
                      platforms: [
                        // combine的flatMap和switchToLatest都要求ios14加才能使用
                        .macOS(.v10_15),
                        .iOS(.v13)
                      ],
                      products: [
                        .library(name: "Networking", targets: ["Networking", "Challenge", "WebSocket"]),
                      ],
                      dependencies: pDependencies,
                      targets: [
                        .target(name: "Networking"),
                        .target(name: "Challenge", dependencies: cDependencies),
                        .target(name: "WebSocket", dependencies: wDependencies),
                        .testTarget(
                            name: "NetworkingTests",
                            dependencies: ["Networking", "Challenge", "WebSocket"]),
                      ])
