import Foundation
import CoreGraphics
import Cocoa

class BeagleOverlayRenderer: OverlayRenderer {
    let overlayType: OverlayType = .beagle
    private var tileSize: Int = 150
    private var lineWidth: Int = 3
    
    func createOverlayView(frame: CGRect, opacity: Int, luminous: Bool, logger: Logger) -> NSView? {
        logger.debug("Creating beagle overlay view with frame: \(frame), luminous: \(luminous)")
        
        let userName = NSUserName()
        let opacityPercentage = Double(opacity) / 255.0 * 100.0
        
        let beagleView = BeagleOverlayView(
            frame: frame,
            tileSize: tileSize,
            lineWidth: lineWidth,
            opacity: opacityPercentage,
            userName: userName
        )
        beagleView.setLuminousEnabled(luminous)
        return beagleView
    }
    
    func renderOverlayImage(size: CGSize, opacity: Int, luminous: Bool, logger: Logger) -> CGImage? {
        logger.debug("Rendering beagle overlay image with size: \(size), luminous: \(luminous)")
        
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
            logger.debug("Failed to create bitmap context for beagle overlay")
            return nil
        }
        
        context.clear(CGRect(origin: .zero, size: size))
        
        let userName = NSUserName()
        let opacityPercentage = Double(opacity) / 255.0 * 100.0
        
        renderBeaglePattern(
            in: context,
            size: size,
            tileSize: tileSize,
            lineWidth: lineWidth,
            opacity: opacityPercentage,
            userName: userName,
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
    
    func setTileSize(_ size: Int) {
        tileSize = size
    }
    
    func setLineWidth(_ width: Int) {
        lineWidth = width
    }
    
    func validateParameters(opacity: Int) throws {
        guard opacity >= 1 && opacity <= 255 else {
            throw WaldoError.invalidOpacity(opacity)
        }
        
        guard tileSize >= 50 && tileSize <= 500 else {
            throw WaldoError.invalidTileSize(tileSize)
        }
        
        guard lineWidth >= 1 && lineWidth <= 10 else {
            throw WaldoError.invalidLineWidth(lineWidth)
        }
    }
    
    private func renderBeaglePattern(in context: CGContext, size: CGSize, tileSize: Int, lineWidth: Int, opacity: Double, userName: String, logger: Logger) {
        let tilesX = Int(ceil(size.width / CGFloat(tileSize)))
        let tilesY = Int(ceil(size.height / CGFloat(tileSize)))
        
        logger.debug("Drawing \(tilesX)x\(tilesY) beagle tiles")
        
        for tileY in 0..<tilesY {
            for tileX in 0..<tilesX {
                let tileRect = CGRect(
                    x: CGFloat(tileX * tileSize),
                    y: CGFloat(tileY * tileSize),
                    width: CGFloat(tileSize),
                    height: CGFloat(tileSize)
                )
                
                renderBeagleTile(
                    in: context,
                    rect: tileRect,
                    lineWidth: lineWidth,
                    opacity: opacity,
                    userName: userName
                )
            }
        }
    }
    
    private func renderBeagleTile(in context: CGContext, rect: CGRect, lineWidth: Int, opacity: Double, userName: String) {
        // Simple wireframe beagle drawing
        let alpha = CGFloat(opacity / 100.0)
        context.setStrokeColor(red: 0.0, green: 0.0, blue: 0.0, alpha: alpha)
        context.setLineWidth(CGFloat(lineWidth))
        
        let centerX = rect.midX
        let centerY = rect.midY
        let scale = min(rect.width, rect.height) * 0.3
        
        // Draw simple beagle outline
        // Head (circle)
        let headRect = CGRect(
            x: centerX - scale * 0.3,
            y: centerY - scale * 0.3,
            width: scale * 0.6,
            height: scale * 0.6
        )
        context.strokeEllipse(in: headRect)
        
        // Body (oval)
        let bodyRect = CGRect(
            x: centerX - scale * 0.4,
            y: centerY + scale * 0.1,
            width: scale * 0.8,
            height: scale * 0.5
        )
        context.strokeEllipse(in: bodyRect)
        
        // Ears
        context.move(to: CGPoint(x: centerX - scale * 0.2, y: centerY - scale * 0.3))
        context.addLine(to: CGPoint(x: centerX - scale * 0.4, y: centerY - scale * 0.5))
        context.move(to: CGPoint(x: centerX + scale * 0.2, y: centerY - scale * 0.3))
        context.addLine(to: CGPoint(x: centerX + scale * 0.4, y: centerY - scale * 0.5))
        context.strokePath()
        
        // Add username text if space allows
        if rect.width > 100 {
            let fontSize = min(rect.width * 0.1, 12.0)
            let font = NSFont.systemFont(ofSize: fontSize)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor(red: 0, green: 0, blue: 0, alpha: alpha)
            ]
            
            let attributedString = NSAttributedString(string: userName, attributes: attributes)
            let textSize = attributedString.size()
            let textRect = CGRect(
                x: centerX - textSize.width / 2,
                y: rect.minY + 5,
                width: textSize.width,
                height: textSize.height
            )
            
            attributedString.draw(in: textRect)
        }
    }
}