import Foundation
import CoreGraphics
import Cocoa

class HybridOverlayRenderer: DataEmbeddingRenderer {
    let overlayType: OverlayType = .hybrid
    
    func createOverlayView(frame: CGRect, opacity: Int, luminous: Bool, watermarkData: String, logger: Logger) -> NSView? {
        logger.debug("Creating hybrid overlay view with frame: \(frame), luminous: \(luminous)")
        
        // Use the existing WatermarkOverlayView for backward compatibility
        let hybridView = WatermarkOverlayView(frame: frame)
        hybridView.updateWatermarkData(watermarkData, opacity: opacity)
        hybridView.setLuminousEnabled(luminous)
        return hybridView
    }
    
    func renderOverlayImage(size: CGSize, opacity: Int, luminous: Bool, watermarkData: String, logger: Logger) -> CGImage? {
        logger.debug("Rendering hybrid overlay image with size: \(size), luminous: \(luminous)")
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            logger.debug("Failed to create bitmap context for hybrid overlay")
            return nil
        }
        
        context.clear(CGRect(origin: .zero, size: size))
        
        // Create base image for LSB steganography
        context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: CGFloat(opacity) / 255.0)
        context.fill(CGRect(origin: .zero, size: size))
        
        guard let baseImage = context.makeImage() else {
            logger.debug("Failed to create base image for hybrid overlay")
            return nil
        }
        
        // Parse watermark data
        let components = watermarkData.components(separatedBy: ":")
        guard components.count >= 4 else {
            logger.debug("Invalid watermark data format for hybrid overlay")
            return nil
        }
        
        let userID = components[0]
        let watermark = components[1..<components.count-1].joined(separator: ":")
        
        // Embed LSB steganography
        logger.debug("Embedding LSB steganography in hybrid overlay")
        guard let lsbImage = SteganographyEngine.embedWatermark(in: baseImage, watermark: watermark, userID: userID) else {
            logger.debug("Failed to embed LSB watermark in hybrid overlay")
            return nil
        }
        
        // Draw the LSB image as base
        context.clear(CGRect(origin: .zero, size: size))
        context.draw(lsbImage, in: CGRect(origin: .zero, size: size))
        
        // Add QR codes on top
        let qrRenderer = QROverlayRenderer()
        qrRenderer.drawCornerQRCodes(
            in: context,
            watermarkData: watermarkData,
            viewSize: size,
            opacity: opacity,
            logger: logger
        )
        
        if luminous {
            LuminousMarkerRenderer.renderLuminousMarkers(
                in: context,
                size: size,
                opacity: opacity,
                avoidCorners: true,
                logger: logger
            )
        }
        
        return context.makeImage()
    }
    
    func validateParameters(opacity: Int) throws {
        guard opacity >= 1 && opacity <= 255 else {
            throw WaldoError.invalidOpacity(opacity)
        }
    }
}