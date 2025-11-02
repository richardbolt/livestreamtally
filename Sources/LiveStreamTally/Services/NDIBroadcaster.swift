//
//  NDIBroadcaster.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import Foundation
import AppKit
import os
import NDIWrapper
import SwiftUI

@MainActor
class NDIBroadcaster: NDIBroadcasterProtocol {
    private var sender: NDIlib_send_instance_t?
    private var isInitialized = false
    private var viewToCapture: NSView?
    private var viewModel: MainViewModel?

    // MARK: - Buffer Pooling

    /// Reusable frame buffer to avoid allocation overhead at 30fps (105 MB/sec churn)
    /// Allocated once during start(), reused for all frames, deallocated in stop()
    private var frameBuffer: UnsafeMutablePointer<UInt8>?

    /// Size of the frame buffer in bytes (3,686,400 bytes)
    /// This represents: width * height * bytes_per_pixel (BGRA = 4 bytes)
    private let bufferSize = NDIConstants.bufferSize


    init() {
        Logger.info("Initializing NDI broadcaster", category: .app)
        guard NDIlib_initialize() else {
            Logger.error("Failed to initialize NDI", category: .app)
            return
        }
        isInitialized = true
    }

    nonisolated deinit {
        // Deinit is nonisolated and cannot access actor-isolated properties
        // The NDI cleanup will happen in the stop() method when called
        // This is the correct approach for @MainActor classes with external resources
        Logger.info("NDI broadcaster deallocated", category: .app)
    }

    func start(name: String, viewModel: MainViewModel) async {
        guard isInitialized else {
            Logger.error("Cannot start NDI - not initialized", category: .app)
            return
        }

        Logger.info("Starting NDI broadcast with name: \(name)", category: .app)

        self.viewModel = viewModel

        guard let window = NSApplication.shared.windows.first,
              let contentView = window.contentView else {
            Logger.error("Could not find main content view", category: .app)
            return
        }

        #if DEBUG
        // Development-only debug logging for view hierarchy analysis
        Logger.info("Window frame: \(window.frame)", category: .app)
        Logger.info("Content view frame: \(contentView.frame)", category: .app)
        Logger.info("Content view actual type: \(String(describing: type(of: contentView)))", category: .app)
        Logger.info("Content view superclass: \(String(describing: type(of: contentView).superclass()))", category: .app)
        Logger.info("Number of subviews: \(contentView.subviews.count)", category: .app)

        // Log all subviews and their types to understand the view hierarchy
        for (index, subview) in contentView.subviews.enumerated() {
            Logger.info("Subview [\(index)] class: \(type(of: subview)), frame: \(subview.frame)", category: .app)

            // Log the class name and any protocols it conforms to
            let mirror = Mirror(reflecting: subview)
            Logger.info("Subview [\(index)] protocols: \(mirror.subjectType)", category: .app)

            // If this is a hosting view, log its type information
            if let hostingView = subview as? NSHostingView<ContentView> {
                Logger.info("Found ContentView hosting view at index \(index)", category: .app)
                self.viewToCapture = hostingView
                break
            }
        }

        if viewToCapture == nil {
            // If we didn't find a hosting view, use the content view itself
            Logger.info("Using content view directly", category: .app)
            self.viewToCapture = contentView
        }
        #else
        // In release builds, skip detailed view hierarchy analysis
        // and directly use the hosting view if found, otherwise fall back to content view
        for subview in contentView.subviews {
            if let hostingView = subview as? NSHostingView<ContentView> {
                self.viewToCapture = hostingView
                break
            }
        }

        if viewToCapture == nil {
            self.viewToCapture = contentView
        }
        #endif


        // Allocate reusable frame buffer once
        frameBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        Logger.info("Allocated frame buffer: \(bufferSize) bytes (\(String(format: "%.2f", Double(bufferSize) / 1_048_576)) MB)", category: .app)

        var sendDesc = NDIlib_send_create_t()
        sender = name.withCString { cString in
            sendDesc.p_ndi_name = UnsafePointer(cString)
            return NDIlib_send_create(&sendDesc)
        }

        guard sender != nil else {
            Logger.error("Failed to create NDI sender", category: .app)
            // Clean up buffer if sender creation fails
            if let buffer = frameBuffer {
                buffer.deallocate()
                frameBuffer = nil
                Logger.info("Deallocated frame buffer after sender creation failure", category: .app)
            }
            return
        }
    }

    func stop() async {
        viewToCapture = nil
        viewModel = nil


        // Deallocate frame buffer
        if let buffer = frameBuffer {
            buffer.deallocate()
            frameBuffer = nil
            Logger.info("Deallocated frame buffer", category: .app)
        }

        if let sender = sender {
            NDIlib_send_destroy(sender)
            self.sender = nil
            Logger.info("NDI broadcast stopped", category: .app)
        }

        // Clean up NDI library if it was initialized
        if isInitialized {
            NDIlib_destroy()
            isInitialized = false
            Logger.info("NDI destroyed", category: .app)
        }
    }

    func sendTally(isLive: Bool, viewerCount: Int, title: String) async {
        guard let sender = sender else {
            Logger.error("Cannot send tally - NDI sender not initialized", category: .app)
            return
        }

        Logger.debug("Sending NDI tally - isLive: \(isLive), viewers: \(viewerCount), title: \(title)", category: .app)

        let metadata = NDIHelpers.formatMetadata(isLive: isLive, viewerCount: viewerCount, title: title)

        metadata.withCString { cString in
            var frame = NDIlib_metadata_frame_t()
            frame.p_data = UnsafeMutablePointer(mutating: cString)
            frame.length = Int32(metadata.utf8.count)
            frame.timecode = Int64(Date().timeIntervalSince1970 * 1000)

            NDIlib_send_send_metadata(sender, &frame)
            Logger.debug("NDI metadata frame sent successfully", category: .app)
        }
    }

    func sendFrame() async {
        guard let sender = sender,
              let viewToCapture = viewToCapture,
              let buffer = frameBuffer else {
            if frameBuffer == nil {
                Logger.error("No frame buffer available - was start() called?", category: .app)
            } else {
                Logger.error("No NDI sender or view available", category: .app)
            }
            return
        }

        // Ensure view is ready for display
        viewToCapture.setNeedsDisplay(viewToCapture.bounds)
        viewToCapture.layoutSubtreeIfNeeded()
        viewToCapture.displayIfNeeded()

        // First capture at view's actual size
        guard let bitmap = viewToCapture.bitmapImageRepForCachingDisplay(in: viewToCapture.bounds) else {
            Logger.error("Failed to create bitmap representation", category: .app)
            return
        }

        viewToCapture.cacheDisplay(in: viewToCapture.bounds, to: bitmap)

        guard let cgImage = bitmap.cgImage else {
            Logger.error("Failed to get CGImage from bitmap", category: .app)
            return
        }

        let targetWidth = NDIConstants.videoWidth
        let targetHeight = NDIConstants.videoHeight
        let targetBytesPerRow = NDIConstants.bytesPerRow

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        // Clear buffer for new frame - ensures no artifacts from previous frames
        // This is a memset operation, which is very fast compared to allocation/deallocation
        buffer.initialize(repeating: 0, count: bufferSize)

        guard let context = CGContext(data: buffer,
                                    width: targetWidth,
                                    height: targetHeight,
                                    bitsPerComponent: 8,
                                    bytesPerRow: targetBytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: bitmapInfo) else {
            Logger.error("Failed to create CGContext", category: .app)
            return
        }

        // Clear the context with a black background
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        // Calculate aspect-preserving dimensions
        let sourceSize = CGSize(width: cgImage.width, height: cgImage.height)
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        let drawRect = NDIHelpers.calculateAspectRatioFit(sourceSize: sourceSize, targetSize: targetSize)

        // Draw with proper aspect ratio
        context.draw(cgImage, in: drawRect)

        var videoFrame = NDIlib_video_frame_v2_t()
        videoFrame.xres = Int32(NDIConstants.videoWidth)
        videoFrame.yres = Int32(NDIConstants.videoHeight)
        videoFrame.FourCC = NDIlib_FourCC_type_BGRA
        videoFrame.frame_rate_N = NDIConstants.frameRateNumerator
        videoFrame.frame_rate_D = NDIConstants.frameRateDenominator
        videoFrame.picture_aspect_ratio = NDIConstants.aspectRatio
        videoFrame.frame_format_type = NDIlib_frame_format_type_progressive
        videoFrame.timecode = Int64(Date().timeIntervalSince1970 * 1000)
        videoFrame.p_data = buffer
        videoFrame.line_stride_in_bytes = Int32(targetBytesPerRow)

        NDIlib_send_send_video_v2(sender, &videoFrame)

        // Buffer is NOT deallocated - it will be reused for the next frame
    }
}
