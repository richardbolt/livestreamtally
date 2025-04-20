import Foundation
import AppKit
import os
import NDIWrapper
import SwiftUI

class NDIBroadcaster {
    private var sender: NDIlib_send_instance_t?
    private var isInitialized = false
    
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
    
    func start(name: String) {
        guard isInitialized else {
            Logger.error("Cannot start NDI - not initialized", category: .app)
            return
        }
        
        Logger.info("Starting NDI broadcast with name: \(name)", category: .app)
        
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
    
    func sendFrame(_ viewModel: MainViewModel) {
        guard let sender = sender else {
            Logger.error("No NDI sender available", category: .app)
            return
        }
        
        // Create the NDI broadcast view
        let ndiView = NDIBroadcastView(viewModel: viewModel)
            .frame(width: 1280, height: 720)
        
        // Create an NSHostingView to render the SwiftUI view
        let hostingView = NSHostingView(rootView: ndiView)
        hostingView.frame = CGRect(x: 0, y: 0, width: 1280, height: 720)
        
        // Force the hosting view to layout
        hostingView.layoutSubtreeIfNeeded()
        
        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            Logger.error("Failed to create bitmap representation", category: .app)
            return
        }
        
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        
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
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        
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