//
//  NDIConstants.swift
//  Live Stream Tally
//
//  Created by Code Review
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import Foundation

/// Constants for NDI video broadcasting configuration
///
/// This enum provides centralized constants for all NDI-related video parameters,
/// ensuring consistency across the codebase and making it easy to modify video
/// specifications in a single location.
enum NDIConstants {
    // MARK: - Video Dimensions

    /// Video frame width in pixels (720p HD)
    static let videoWidth = 1280

    /// Video frame height in pixels (720p HD)
    static let videoHeight = 720

    /// Target aspect ratio (16:9 for HD content)
    static let aspectRatio: Float = 16.0 / 9.0

    // MARK: - Frame Rate

    /// Frame rate numerator in NDI format (30000/1000 = 30 fps)
    ///
    /// NDI uses a rational frame rate representation with numerator/denominator.
    /// This format allows for precise fractional frame rates (e.g., 29.97 fps would be 30000/1001).
    static let frameRateNumerator: Int32 = 30000

    /// Frame rate denominator in NDI format (30000/1000 = 30 fps)
    static let frameRateDenominator: Int32 = 1000

    /// Frame rate as double for timer calculations (30 fps)
    static let framesPerSecond: Double = 30.0

    /// Time interval between frames in seconds (1/30 = 0.0333...)
    ///
    /// Used for Timer.publish intervals to achieve target frame rate
    static let frameInterval: Double = 1.0 / framesPerSecond

    // MARK: - Pixel Format

    /// Bytes per pixel for BGRA format
    ///
    /// BGRA is a 32-bit pixel format with 8 bits each for Blue, Green, Red, and Alpha channels
    static let bytesPerPixel = 4

    /// Total buffer size needed for one frame (width * height * bytesPerPixel)
    ///
    /// Pre-calculated buffer size: 1280 * 720 * 4 = 3,686,400 bytes (~3.5 MB per frame)
    static let bufferSize = videoWidth * videoHeight * bytesPerPixel

    // MARK: - Computed Properties

    /// Bytes per row (stride) for current video width
    ///
    /// Calculated as width * bytesPerPixel for the configured resolution
    static var bytesPerRow: Int {
        videoWidth * bytesPerPixel
    }

    /// Frame rate as string description for logging
    ///
    /// Returns a human-readable description like "30000/1000 (30 fps)"
    static var frameRateDescription: String {
        "\(frameRateNumerator)/\(frameRateDenominator) (\(Int(framesPerSecond)) fps)"
    }
}
