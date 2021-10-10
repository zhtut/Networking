// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(name: "SSNetwork",
                      products: [
                        .library(name: "SSNetwork", targets: ["SSNetwork"]),
                      ],
                      targets: [
                        .target(name: "SSNetwork"),
                      ])
