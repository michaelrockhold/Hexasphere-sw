// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Hexasphere",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Hexasphere",
            targets: ["Hexasphere"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-algorithms", from: "0.2.0"),
        .package(url: "https://github.com/apple/swift-numerics", from: "0.1.0"),
        .package(url: "https://github.com/Bersaelor/KDTree", from: "1.4.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Hexasphere",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Numerics", package: "swift-numerics"),
                .product(name: "KDTree", package: "KDTree")
            ]),
        .testTarget(
            name: "HexasphereTests",
            dependencies: ["Hexasphere"]),
    ]
)
