import Foundation
import CoreGraphics

struct LuminousMarkerRenderer {
    
    static func renderLuminousMarkers(in context: CGContext, size: CGSize, opacity: Int, logger: Logger) {
        renderLuminousMarkers(in: context, size: size, opacity: opacity, avoidCorners: false, logger: logger)
    }
    
    static func renderLuminousMarkers(in context: CGContext, size: CGSize, opacity: Int, avoidCorners: Bool, logger: Logger) {
        let markerSize = LuminousOverlayConstants.CORNER_PATTERN_SIZE
        let margin = size.width * LuminousOverlayConstants.MARGIN_PERCENTAGE
        
        let positions: [CGPoint]
        
        if avoidCorners {
            // Place markers on the edges between corners to avoid QR code overlap
            let qrSize = CGFloat(WatermarkConstants.QR_VERSION2_PIXEL_SIZE)
            let qrMargin = CGFloat(WatermarkConstants.QR_VERSION2_MARGIN)
            let _ = qrSize + qrMargin + 20 // QR clearance calculated but positioning is based on center/edge logic
            
            positions = [
                // Top edge, center
                CGPoint(x: size.width/2 - markerSize/2, y: margin),
                // Bottom edge, center  
                CGPoint(x: size.width/2 - markerSize/2, y: size.height - markerSize - margin),
                // Left edge, between QR codes
                CGPoint(x: margin, y: size.height/2 - markerSize/2),
                // Right edge, between QR codes
                CGPoint(x: size.width - markerSize - margin, y: size.height/2 - markerSize/2)
            ]
        } else {
            // Original corner positions for standalone luminous overlay
            positions = [
                CGPoint(x: margin, y: margin),
                CGPoint(x: size.width - markerSize - margin, y: margin),
                CGPoint(x: margin, y: size.height - markerSize - margin),
                CGPoint(x: size.width - markerSize - margin, y: size.height - markerSize - margin)
            ]
        }
        
        for position in positions {
            renderLuminanceMarker(
                in: context,
                at: position,
                size: markerSize,
                opacity: opacity
            )
        }
        
        let positionType = avoidCorners ? "edge" : "corner"
        logger.debug("Rendered luminous markers at \(positions.count) \(positionType) positions")
    }
    
    private static func renderLuminanceMarker(in context: CGContext, at position: CGPoint, size: CGFloat, opacity: Int) {
        // Create a high-contrast luminance pattern for detection
        let steps = LuminousOverlayConstants.GRADIENT_STEPS
        let stepSize = size / CGFloat(steps)
        
        for step in 0..<steps {
            let luminance = LuminousOverlayConstants.MIN_LUMINANCE +
                (LuminousOverlayConstants.MAX_LUMINANCE - LuminousOverlayConstants.MIN_LUMINANCE) *
                CGFloat(step) / CGFloat(steps - 1)
            
            let color = CGColor(red: luminance, green: luminance, blue: luminance, alpha: CGFloat(opacity) / 255.0)
            context.setFillColor(color)
            
            let stepRect = CGRect(
                x: position.x + CGFloat(step) * stepSize,
                y: position.y,
                width: stepSize,
                height: size
            )
            
            context.fill(stepRect)
        }
    }
}