import Foundation
import AppKit
import os
import NDIWrapper

class NDIBroadcaster {
    private var sender: NDIlib_send_instance_t?
    private var isInitialized = false
    private let logger = Logger.logger(for: .app)
    
    init() {
        os_log("Initializing NDI broadcaster", log: logger, type: .info)
        guard NDIlib_initialize() else {
            os_log("Failed to initialize NDI", log: logger, type: .error)
            return
        }
        isInitialized = true
    }
    
    deinit {
        stop()
        if isInitialized {
            NDIlib_destroy()
            os_log("NDI destroyed", log: logger, type: .info)
        }
    }
    
    func start(name: String) {
        guard isInitialized else {
            os_log("Cannot start NDI - not initialized", log: logger, type: .error)
            return
        }
        
        os_log("Starting NDI broadcast with name: %{public}@", log: logger, type: .info, name)
        
        var sendDesc = NDIlib_send_create_t()
        name.withCString { cString in
            sendDesc.p_ndi_name = UnsafePointer(strdup(cString))
        }
        
        sender = NDIlib_send_create(&sendDesc)
        
        guard sender != nil else {
            os_log("Failed to create NDI sender", log: logger, type: .error)
            return
        }
    }
    
    func stop() {
        if let sender = sender {
            NDIlib_send_destroy(sender)
            self.sender = nil
            os_log("NDI broadcast stopped", log: logger, type: .info)
        }
    }
    
    func sendTally(isLive: Bool, viewerCount: Int, title: String) {
        guard let sender = sender else {
            os_log("Cannot send tally - NDI sender not initialized", log: logger, type: .error)
            return
        }
        
        os_log("Sending NDI tally - isLive: %{public}@, viewers: %{public}d, title: %{public}@", 
              log: logger, type: .debug, 
              isLive ? "true" : "false", viewerCount, title)
        
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
    
    func sendFrame(_ view: NSView) {
        guard let sender = sender else {
            os_log("No NDI sender available", log: logger, type: .error)
            return
        }
        
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            os_log("Failed to create bitmap representation", log: logger, type: .error)
            return
        }
        
        view.cacheDisplay(in: view.bounds, to: bitmap)
        
        guard let cgImage = bitmap.cgImage else {
            os_log("Failed to get CGImage from bitmap", log: logger, type: .error)
            return
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bitsPerComponent = cgImage.bitsPerComponent
        let bytesPerRow = cgImage.bytesPerRow
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: height * bytesPerRow)
        
        guard let context = CGContext(data: buffer,
                                    width: width,
                                    height: height,
                                    bitsPerComponent: bitsPerComponent,
                                    bytesPerRow: bytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: bitmapInfo) else {
            buffer.deallocate()
            os_log("Failed to create CGContext", log: logger, type: .error)
            return
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var videoFrame = NDIlib_video_frame_v2_t()
        videoFrame.xres = Int32(width)
        videoFrame.yres = Int32(height)
        videoFrame.FourCC = NDIlib_FourCC_type_BGRA
        videoFrame.frame_rate_N = 30000
        videoFrame.frame_rate_D = 1000
        videoFrame.picture_aspect_ratio = Float(width) / Float(height)
        videoFrame.frame_format_type = NDIlib_frame_format_type_progressive
        videoFrame.timecode = Int64(Date().timeIntervalSince1970 * 1000)
        videoFrame.p_data = buffer
        videoFrame.line_stride_in_bytes = Int32(bytesPerRow)
        
        NDIlib_send_send_video_v2(sender, &videoFrame)
        
        buffer.deallocate()
    }
} 