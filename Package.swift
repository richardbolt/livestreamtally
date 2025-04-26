// swift-tools-version:6.1
//
// Package.swift
// LiveStreamTally
//
// Created by Richard Bolt
// Copyright © 2025 Richard Bolt. All rights reserved.
//
// This file is part of LiveStreamTally, released under the MIT License.
// See the LICENSE file for details.
//

import PackageDescription

let package = Package(
    name: "LiveStreamTally",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "LiveStreamTally",
            targets: ["LiveStreamTally"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/google/google-api-objectivec-client-for-rest.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
    ],
    targets: [
        .executableTarget(
            name: "LiveStreamTally",
            dependencies: [
                .product(name: "GoogleAPIClientForREST_YouTube", package: "google-api-objectivec-client-for-rest"),
                .product(name: "Logging", package: "swift-log"),
                "NDIWrapper"
            ],
            path: "Sources/LiveStreamTally",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .unsafeFlags([
                    "-L/Library/NDI SDK for Apple/lib/macOS",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"
                ]),
                .linkedLibrary("ndi")
            ]
        ),
        .systemLibrary(
            name: "NDIWrapper",
            path: "Sources/NDIWrapper"
        )
    ]
) 