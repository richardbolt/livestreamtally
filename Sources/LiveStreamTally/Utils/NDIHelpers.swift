//
//  NDIHelpers.swift
//  LiveStreamTally
//
//  Pure helper functions for NDI integration
//

import Foundation
import CoreGraphics

/// Pure helper functions for NDI metadata formatting and calculations
enum NDIHelpers {

    /// Formats NDI metadata as XML string
    /// - Parameters:
    ///   - isLive: Whether the stream is currently live
    ///   - viewerCount: Number of current viewers
    ///   - title: Stream title
    /// - Returns: XML formatted metadata string
    static func formatMetadata(isLive: Bool, viewerCount: Int, title: String) -> String {
        var metadata = "<ndi_metadata "
        metadata += "isLive=\"\(isLive ? "true" : "false")\" "
        metadata += "viewerCount=\"\(viewerCount)\" "
        metadata += "title=\"\(escapeXML(title))\" "
        metadata += "/>"
        return metadata
    }

    /// Escapes special XML characters in a string
    /// - Parameter string: Input string to escape
    /// - Returns: XML-safe string with escaped characters
    static func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Calculates aspect-ratio-preserving rectangle to fit source into target
    /// - Parameters:
    ///   - sourceSize: Size of the source content
    ///   - targetSize: Size of the target container
    /// - Returns: Rectangle positioned to center the content with preserved aspect ratio
    static func calculateAspectRatioFit(sourceSize: CGSize, targetSize: CGSize) -> CGRect {
        let sourceAspect = sourceSize.width / sourceSize.height
        let targetAspect = targetSize.width / targetSize.height

        var drawRect = CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)

        if sourceAspect > targetAspect {
            // Source is wider - fit to width
            let newHeight = targetSize.width / sourceAspect
            let yOffset = (targetSize.height - newHeight) / 2
            drawRect = CGRect(x: 0, y: yOffset, width: targetSize.width, height: newHeight)
        } else {
            // Source is taller or same aspect - fit to height
            let newWidth = targetSize.height * sourceAspect
            let xOffset = (targetSize.width - newWidth) / 2
            drawRect = CGRect(x: xOffset, y: 0, width: newWidth, height: targetSize.height)
        }

        return drawRect
    }
}
