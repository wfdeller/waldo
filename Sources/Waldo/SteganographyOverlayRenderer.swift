import Foundation
import CoreGraphics
import Cocoa

class SteganographyOverlayRenderer: DataEmbeddingRenderer {
    let overlayType: OverlayType = .steganography
    
    func createOverlayView(frame: CGRect, opacity: Int, luminous: Bool, watermarkData: String, logger: Logger) -> NSView? {
        logger.debug("Creating steganography overlay view with frame: \(frame), luminous: \(luminous)")
        let steganographyView = SteganographyOverlayView(frame: frame)
        steganographyView.updateWatermarkData(watermarkData, opacity: opacity, luminous: luminous)
        return steganographyView
    }
    
    func renderOverlayImage(size: CGSize, opacity: Int, luminous: Bool, watermarkData: String, logger: Logger) -> CGImage? {
        logger.debug("Rendering steganography overlay image with size: \(size), luminous: \(luminous)")
        
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
            logger.debug("Failed to create bitmap context for steganography overlay")
            return nil
        }
        
        // Create a neutral base image for LSB embedding
        context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: CGFloat(opacity) / 255.0)
        context.fill(CGRect(origin: .zero, size: size))
        
        guard let baseImage = context.makeImage() else {
            logger.debug("Failed to create base image for steganography")
            return nil
        }
        
        // Parse watermark data
        let components = watermarkData.components(separatedBy: ":")
        guard components.count >= 4 else {
            logger.debug("Invalid watermark data format for steganography")
            return nil
        }
        
        let userID = components[0]
        let watermark = components[1..<components.count-1].joined(separator: ":")
        
        logger.debug("Embedding LSB steganography for user: \(userID)")
        
        // Embed watermark using existing SteganographyEngine
        guard let steganographyImage = SteganographyEngine.embedWatermark(in: baseImage, watermark: watermark, userID: userID) else {
            logger.debug("Failed to embed LSB watermark")
            return nil
        }
        
        if luminous {
            // Create new context for adding luminous markers on top of steganographic image
            context.clear(CGRect(origin: .zero, size: size))
            context.draw(steganographyImage, in: CGRect(origin: .zero, size: size))
            
            LuminousMarkerRenderer.renderLuminousMarkers(
                in: context,
                size: size,
                opacity: opacity,
                avoidCorners: true,
                logger: logger
            )
            
            return context.makeImage()
        }
        
        return steganographyImage
    }
    
    func validateParameters(opacity: Int) throws {
        guard opacity >= 1 && opacity <= 255 else {
            throw WaldoError.invalidOpacity(opacity)
        }
        
        // For steganography, very low opacity values might interfere with LSB embedding
        if opacity < 10 {
            throw WaldoError.invalidOpacity(opacity)
        }
    }
}

class SteganographyOverlayView: NSView {
    private var watermarkData: String = ""
    private var opacity: Int = WatermarkConstants.ALPHA_OPACITY
    private var luminous: Bool = false
    private var embeddedImage: CGImage?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    func updateWatermarkData(_ newData: String, opacity: Int = WatermarkConstants.ALPHA_OPACITY, luminous: Bool = false) {
        watermarkData = newData
        self.opacity = opacity
        self.luminous = luminous
        generateEmbeddedImage()
        needsDisplay = true
    }
    
    private func generateEmbeddedImage() {
        guard !watermarkData.isEmpty else { return }
        
        let logger = Logger()
        let renderer = SteganographyOverlayRenderer()
        
        embeddedImage = renderer.renderOverlayImage(
            size: bounds.size,
            opacity: opacity,
            luminous: luminous,
            watermarkData: watermarkData,
            logger: logger
        )
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext,
              let image = embeddedImage else { return }
        
        context.draw(image, in: bounds)
    }
    
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        
        // Regenerate embedded image when view size changes
        if bounds.size != oldSize {
            generateEmbeddedImage()
            needsDisplay = true
        }
    }
    
    override var isOpaque: Bool { return false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { return false }
    override func hitTest(_ point: NSPoint) -> NSView? { return nil }
}