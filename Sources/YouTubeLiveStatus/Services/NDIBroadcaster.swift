//
//  NDIBroadcaster.swift
//  YouTubeLiveStatus
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of YouTubeLiveStatus, released under the MIT License.
//  See the LICENSE file for details.
//

import Foundation
import AppKit
import os
import NDIWrapper
import SwiftUI

class NDIBroadcaster {
    private var sender: NDIlib_send_instance_t?
    private var isInitialized = false
    private var viewToCapture: NSView?
    private var viewModel: MainViewModel?
    
    init() {
        Logger.info("Initializing NDI broadcaster", category: .app)
        guard NDIlib_initialize() else {
            Logger.error("Failed to initialize NDI", category: .app)
            return
        }
        isInitialized = true
    }
    
    deinit {
        stop()
        if isInitialized {
            NDIlib_destroy()
            Logger.info("NDI destroyed", category: .app)
        }
    }
    
    func start(name: String, viewModel: MainViewModel) {
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
        
        var sendDesc = NDIlib_send_create_t()
        name.withCString { cString in
            sendDesc.p_ndi_name = UnsafePointer(strdup(cString))
        }
        
        sender = NDIlib_send_create(&sendDesc)
        
        guard sender != nil else {
            Logger.error("Failed to create NDI sender", category: .app)
            return
        }
    }
    
    func stop() {
        viewToCapture = nil
        viewModel = nil
        if let sender = sender {
            NDIlib_send_destroy(sender)
            self.sender = nil
            Logger.info("NDI broadcast stopped", category: .app)
        }
    }
    
    func sendTally(isLive: Bool, viewerCount: Int, title: String) {
        guard let sender = sender else {
            Logger.error("Cannot send tally - NDI sender not initialized", category: .app)
            return
        }
        
        Logger.debug("Sending NDI tally - isLive: \(isLive), viewers: \(viewerCount), title: \(title)", category: .app)
        
        var metadata = "<ndi_metadata "
        metadata += "isLive=\"\(isLive ? "true" : "false")\" "
        metadata += "viewerCount=\"\(viewerCount)\" "
        metadata += "title=\"\(title.replacingOccurrences(of: "\"", with: "&quot;"))\" "
        metadata += "/>"
        
        metadata.withCString { cString in
            var frame = NDIlib_metadata_frame_t()
            frame.p_data = UnsafeMutablePointer(mutating: cString)
            frame.length = Int32(metadata.utf8.count)
            frame.timecode = Int64(Date().timeIntervalSince1970 * 1000)
            
            NDIlib_send_send_metadata(sender, &frame)
        }
    }
    
    func sendFrame() {
        guard let sender = sender,
              let viewToCapture = viewToCapture else {
            Logger.error("No NDI sender or view available", category: .app)
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
        
        let targetWidth = 1280
        let targetHeight = 720
        let targetBytesPerRow = targetWidth * 4
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: targetHeight * targetBytesPerRow)
        
        guard let context = CGContext(data: buffer,
                                    width: targetWidth,
                                    height: targetHeight,
                                    bitsPerComponent: 8,
                                    bytesPerRow: targetBytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: bitmapInfo) else {
            buffer.deallocate()
            Logger.error("Failed to create CGContext", category: .app)
            return
        }
        
        // Clear the context with a black background
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        
        // Calculate aspect-preserving dimensions
        let sourceAspect = Double(cgImage.width) / Double(cgImage.height)
        let targetAspect = Double(targetWidth) / Double(targetHeight)
        
        var drawRect = CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
        
        if sourceAspect > targetAspect {
            // Source is wider - fit to width
            let newHeight = Double(targetWidth) / sourceAspect
            let yOffset = (Double(targetHeight) - newHeight) / 2
            drawRect = CGRect(x: 0, y: yOffset, width: Double(targetWidth), height: newHeight)
        } else {
            // Source is taller - fit to height
            let newWidth = Double(targetHeight) * sourceAspect
            let xOffset = (Double(targetWidth) - newWidth) / 2
            drawRect = CGRect(x: xOffset, y: 0, width: newWidth, height: Double(targetHeight))
        }
        
        // Draw with proper aspect ratio
        context.draw(cgImage, in: drawRect)
        
        var videoFrame = NDIlib_video_frame_v2_t()
        videoFrame.xres = Int32(targetWidth)
        videoFrame.yres = Int32(targetHeight)
        videoFrame.FourCC = NDIlib_FourCC_type_BGRA
        videoFrame.frame_rate_N = 30000
        videoFrame.frame_rate_D = 1000
        videoFrame.picture_aspect_ratio = 16.0/9.0
        videoFrame.frame_format_type = NDIlib_frame_format_type_progressive
        videoFrame.timecode = Int64(Date().timeIntervalSince1970 * 1000)
        videoFrame.p_data = buffer
        videoFrame.line_stride_in_bytes = Int32(targetBytesPerRow)
        
        NDIlib_send_send_video_v2(sender, &videoFrame)
        
        buffer.deallocate()
    }
} 