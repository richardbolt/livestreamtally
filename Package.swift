// swift-tools-version:6.1
//
// Package.swift
// YouTubeLiveStatus
//
// Created by Richard Bolt
// Copyright © 2025 Richard Bolt. All rights reserved.
//
// This file is part of YouTubeLiveStatus, released under the MIT License.
// See the LICENSE file for details.
//

import PackageDescription

let package = Package(
    name: "YouTubeLiveStatus",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "YouTubeLiveStatus",
            targets: ["YouTubeLiveStatus"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/google/google-api-objectivec-client-for-rest.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
    ],
    targets: [
        .executableTarget(
            name: "YouTubeLiveStatus",
            dependencies: [
                .product(name: "GoogleAPIClientForREST_YouTube", package: "google-api-objectivec-client-for-rest"),
                .product(name: "Logging", package: "swift-log"),
                "NDIWrapper"
            ],
            path: "Sources/YouTubeLiveStatus",
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