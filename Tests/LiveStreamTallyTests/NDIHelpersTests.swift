//
//  NDIHelpersTests.swift
//  LiveStreamTallyTests
//
//  Tests for NDI helper functions
//

import Testing
import Foundation
import CoreGraphics
@testable import LiveStreamTally

@Suite("NDI Helpers Tests")
struct NDIHelpersTests {

    // MARK: - formatMetadata Tests

    @Test("formatMetadata creates valid XML structure")
    func formatMetadata_creates_valid_xml() {
        // Act
        let metadata = NDIHelpers.formatMetadata(isLive: true, viewerCount: 100, title: "Test Stream")

        // Assert
        #expect(metadata.hasPrefix("<ndi_metadata "), "Should start with opening tag")
        #expect(metadata.hasSuffix("/>"), "Should end with self-closing tag")
        #expect(metadata.contains("isLive="), "Should contain isLive attribute")
        #expect(metadata.contains("viewerCount="), "Should contain viewerCount attribute")
        #expect(metadata.contains("title="), "Should contain title attribute")
    }

    @Test("formatMetadata with live status true")
    func formatMetadata_with_live_true() {
        // Act
        let metadata = NDIHelpers.formatMetadata(isLive: true, viewerCount: 50, title: "Live Now")

        // Assert
        #expect(metadata.contains("isLive=\"true\""), "Should show isLive as true")
        #expect(metadata.contains("viewerCount=\"50\""), "Should include viewer count")
        #expect(metadata.contains("title=\"Live Now\""), "Should include title")
    }

    @Test("formatMetadata with live status false")
    func formatMetadata_with_live_false() {
        // Act
        let metadata = NDIHelpers.formatMetadata(isLive: false, viewerCount: 0, title: "Offline")

        // Assert
        #expect(metadata.contains("isLive=\"false\""), "Should show isLive as false")
        #expect(metadata.contains("viewerCount=\"0\""), "Should show zero viewers")
        #expect(metadata.contains("title=\"Offline\""), "Should include offline title")
    }

    @Test("formatMetadata escapes special characters in title")
    func formatMetadata_escapes_special_characters() {
        // Act
        let metadata = NDIHelpers.formatMetadata(
            isLive: true,
            viewerCount: 100,
            title: "Test \"Stream\" & <Tags>"
        )

        // Assert
        #expect(metadata.contains("&quot;"), "Should escape double quotes")
        #expect(metadata.contains("&amp;"), "Should escape ampersands")
        #expect(metadata.contains("&lt;"), "Should escape less-than")
        #expect(metadata.contains("&gt;"), "Should escape greater-than")
        #expect(!metadata.contains("\"Stream\""), "Should not contain unescaped quotes")
        #expect(!metadata.contains(" & "), "Should not contain unescaped ampersand")
    }

    @Test("formatMetadata with large viewer count")
    func formatMetadata_with_large_viewer_count() {
        // Act
        let metadata = NDIHelpers.formatMetadata(isLive: true, viewerCount: 1_000_000, title: "Popular Stream")

        // Assert
        #expect(metadata.contains("viewerCount=\"1000000\""), "Should handle large numbers")
    }

    @Test("formatMetadata with empty title")
    func formatMetadata_with_empty_title() {
        // Act
        let metadata = NDIHelpers.formatMetadata(isLive: false, viewerCount: 0, title: "")

        // Assert
        #expect(metadata.contains("title=\"\""), "Should handle empty title")
        #expect(metadata.hasPrefix("<ndi_metadata "), "Should still be valid XML")
        #expect(metadata.hasSuffix("/>"), "Should still close properly")
    }

    // MARK: - escapeXML Tests

    @Test("escapeXML escapes double quotes")
    func escapeXML_escapes_quotes() {
        // Act
        let result = NDIHelpers.escapeXML("Say \"Hello\"")

        // Assert
        #expect(result == "Say &quot;Hello&quot;", "Should escape double quotes")
    }

    @Test("escapeXML escapes ampersands")
    func escapeXML_escapes_ampersands() {
        // Act
        let result = NDIHelpers.escapeXML("Tom & Jerry")

        // Assert
        #expect(result == "Tom &amp; Jerry", "Should escape ampersands")
    }

    @Test("escapeXML escapes less-than and greater-than")
    func escapeXML_escapes_angle_brackets() {
        // Act
        let result = NDIHelpers.escapeXML("<html>")

        // Assert
        #expect(result == "&lt;html&gt;", "Should escape angle brackets")
    }

    @Test("escapeXML escapes single quotes")
    func escapeXML_escapes_single_quotes() {
        // Act
        let result = NDIHelpers.escapeXML("It's working")

        // Assert
        #expect(result == "It&apos;s working", "Should escape single quotes")
    }

    @Test("escapeXML handles multiple special characters")
    func escapeXML_handles_multiple_characters() {
        // Act
        let result = NDIHelpers.escapeXML("\"Quote\" & <Tag> with 'apostrophe'")

        // Assert
        #expect(result.contains("&quot;"), "Should escape quotes")
        #expect(result.contains("&amp;"), "Should escape ampersand")
        #expect(result.contains("&lt;"), "Should escape less-than")
        #expect(result.contains("&gt;"), "Should escape greater-than")
        #expect(result.contains("&apos;"), "Should escape apostrophe")
    }

    @Test("escapeXML preserves normal characters")
    func escapeXML_preserves_normal_characters() {
        // Act
        let result = NDIHelpers.escapeXML("Normal text 123")

        // Assert
        #expect(result == "Normal text 123", "Should not modify normal text")
    }

    @Test("escapeXML handles empty string")
    func escapeXML_handles_empty_string() {
        // Act
        let result = NDIHelpers.escapeXML("")

        // Assert
        #expect(result == "", "Should return empty string")
    }

    // MARK: - calculateAspectRatioFit Tests

    @Test("calculateAspectRatioFit with wider source")
    func calculateAspectRatioFit_wider_source() {
        // Arrange - 16:9 source into 4:3 target
        let sourceSize = CGSize(width: 1920, height: 1080) // 16:9
        let targetSize = CGSize(width: 800, height: 600)   // 4:3

        // Act
        let result = NDIHelpers.calculateAspectRatioFit(sourceSize: sourceSize, targetSize: targetSize)

        // Assert
        #expect(result.width == 800, "Should fit to width")
        #expect(result.height < 600, "Height should be less than target")
        #expect(result.minX == 0, "Should be left-aligned")
        #expect(result.minY > 0, "Should be vertically centered")

        // Verify aspect ratio is preserved
        let sourceAspect = sourceSize.width / sourceSize.height
        let resultAspect = result.width / result.height
        #expect(abs(sourceAspect - resultAspect) < 0.01, "Aspect ratio should be preserved")
    }

    @Test("calculateAspectRatioFit with taller source")
    func calculateAspectRatioFit_taller_source() {
        // Arrange - 4:3 source into 16:9 target
        let sourceSize = CGSize(width: 800, height: 600)   // 4:3
        let targetSize = CGSize(width: 1920, height: 1080) // 16:9

        // Act
        let result = NDIHelpers.calculateAspectRatioFit(sourceSize: sourceSize, targetSize: targetSize)

        // Assert
        #expect(result.height == 1080, "Should fit to height")
        #expect(result.width < 1920, "Width should be less than target")
        #expect(result.minX > 0, "Should be horizontally centered")
        #expect(result.minY == 0, "Should be top-aligned")

        // Verify aspect ratio is preserved
        let sourceAspect = sourceSize.width / sourceSize.height
        let resultAspect = result.width / result.height
        #expect(abs(sourceAspect - resultAspect) < 0.01, "Aspect ratio should be preserved")
    }

    @Test("calculateAspectRatioFit with same aspect ratio")
    func calculateAspectRatioFit_same_aspect() {
        // Arrange - 16:9 source into 16:9 target (different sizes)
        let sourceSize = CGSize(width: 1920, height: 1080)
        let targetSize = CGSize(width: 1280, height: 720)

        // Act
        let result = NDIHelpers.calculateAspectRatioFit(sourceSize: sourceSize, targetSize: targetSize)

        // Assert
        #expect(result.width == 1280, "Should fill width")
        #expect(result.height == 720, "Should fill height")
        #expect(result.minX == 0, "Should have no X offset")
        #expect(result.minY == 0, "Should have no Y offset")

        // Result should exactly match target
        #expect(result.size == targetSize, "Should exactly match target size")
    }

    @Test("calculateAspectRatioFit with square source into wide target")
    func calculateAspectRatioFit_square_to_wide() {
        // Arrange - 1:1 source into 16:9 target
        let sourceSize = CGSize(width: 1000, height: 1000) // Square
        let targetSize = CGSize(width: 1920, height: 1080) // 16:9

        // Act
        let result = NDIHelpers.calculateAspectRatioFit(sourceSize: sourceSize, targetSize: targetSize)

        // Assert
        #expect(result.height == 1080, "Should fit to height")
        #expect(result.width == 1080, "Width should match height (square)")
        #expect(result.minX > 0, "Should be horizontally centered")
        #expect(result.minY == 0, "Should be top-aligned")

        // Verify it's still square
        #expect(result.width == result.height, "Should maintain square aspect")
    }

    @Test("calculateAspectRatioFit with wide source into square target")
    func calculateAspectRatioFit_wide_to_square() {
        // Arrange - 16:9 source into 1:1 target
        let sourceSize = CGSize(width: 1920, height: 1080)
        let targetSize = CGSize(width: 1000, height: 1000)

        // Act
        let result = NDIHelpers.calculateAspectRatioFit(sourceSize: sourceSize, targetSize: targetSize)

        // Assert
        #expect(result.width == 1000, "Should fit to width")
        #expect(result.height < 1000, "Height should be less than target")
        #expect(result.minX == 0, "Should be left-aligned")
        #expect(result.minY > 0, "Should be vertically centered")

        // Verify aspect ratio is preserved
        let sourceAspect = sourceSize.width / sourceSize.height
        let resultAspect = result.width / result.height
        #expect(abs(sourceAspect - resultAspect) < 0.01, "Aspect ratio should be preserved")
    }

    @Test("calculateAspectRatioFit with portrait source")
    func calculateAspectRatioFit_portrait_source() {
        // Arrange - 9:16 portrait source into 16:9 landscape target
        let sourceSize = CGSize(width: 1080, height: 1920) // Portrait
        let targetSize = CGSize(width: 1920, height: 1080) // Landscape

        // Act
        let result = NDIHelpers.calculateAspectRatioFit(sourceSize: sourceSize, targetSize: targetSize)

        // Assert
        #expect(result.height == 1080, "Should fit to height")
        #expect(result.width < targetSize.width, "Should not fill width")
        #expect(result.minX > 0, "Should be horizontally centered")
        #expect(result.minY == 0, "Should be top-aligned")

        // Verify aspect ratio is preserved
        let sourceAspect = sourceSize.width / sourceSize.height
        let resultAspect = result.width / result.height
        #expect(abs(sourceAspect - resultAspect) < 0.01, "Aspect ratio should be preserved")
    }

    @Test("calculateAspectRatioFit centers content")
    func calculateAspectRatioFit_centers_content() {
        // Arrange
        let sourceSize = CGSize(width: 1920, height: 1080)
        let targetSize = CGSize(width: 1000, height: 1000)

        // Act
        let result = NDIHelpers.calculateAspectRatioFit(sourceSize: sourceSize, targetSize: targetSize)

        // Assert - Verify centering
        let verticalPadding = targetSize.height - result.height
        let topPadding = result.minY
        let bottomPadding = verticalPadding - topPadding

        #expect(abs(topPadding - bottomPadding) < 0.1, "Should be vertically centered")
    }
}
