// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


var pDependencies = [PackageDescription.Package.Dependency]()
var cDependencies = [PackageDescription.Target.Dependency]()
var wDependencies = [PackageDescription.Target.Dependency]()

#if os(macOS) || os(iOS)
// ios 和 macos不需要这个，系统自带了
#else
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
#endif

var targets = [Target]()
targets.append(.target(name: "Networking"))
targets.append(.target(name: "WebSocket", dependencies: wDependencies))
#if os(macOS) || os(iOS)
// linux等不支持Challenge
targets.append(.target(name: "Challenge", dependencies: cDependencies))
#endif

var testTargetDependencies = [PackageDescription.Target.Dependency]()
testTargetDependencies.append("Networking")
testTargetDependencies.append("WebSocket")
#if os(macOS) || os(iOS)
// linux等不支持Challenge
testTargetDependencies.append("Challenge")
#endif
targets.append(.testTarget(name: "NetworkingTests", dependencies: testTargetDependencies))

let package = Package(name: "Networking",
                      platforms: [
                        .macOS(.v10_15),
                        .iOS(.v13)
                      ],
                      products: [
                        .library(name: "Networking", targets: targets.dropLast().map({ $0.name })),
                      ],
                      dependencies: pDependencies,
                      targets: targets)
