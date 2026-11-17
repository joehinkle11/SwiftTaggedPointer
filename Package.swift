// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftTaggedPointer",
    products: [
        // Products declare the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftTaggedPointer",
            targets: ["SwiftTaggedPointer"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftTaggedPointer"),
        // Executable checks instead of a test target: test targets are not
        // supported in Embedded Swift, so the checks run as a plain
        // executable on every platform (host, wasm, wasm-embedded).
        .executableTarget(
            name: "TaggedPointerChecks",
            dependencies: ["SwiftTaggedPointer"]),
    ]
)
