import Cocoa
import CoreGraphics

class BeagleOverlayView: NSView {
    
    private let tileSize: Int
    private let lineWidth: Int
    private let opacity: Double
    private let userName: String
    
    init(frame frameRect: NSRect, tileSize: Int, lineWidth: Int, opacity: Double, userName: String) {
        self.tileSize = tileSize
        self.lineWidth = lineWidth
        self.opacity = opacity
        self.userName = userName
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        self.tileSize = 150
        self.lineWidth = 3
        self.opacity = 5.0
        self.userName = NSUserName()
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Sample desktop background color and create adaptive color
        let adaptiveColor = getAdaptiveColor()
        let alphaComponent = opacity / 100.0
        
        // Set drawing properties with adaptive color and configurable opacity
        context.setStrokeColor(adaptiveColor.withAlphaComponent(alphaComponent).cgColor)
        context.setLineWidth(CGFloat(lineWidth))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        // Calculate how many tiles fit in the view
        let tilesX = Int(bounds.width) / tileSize + 1
        let tilesY = Int(bounds.height) / tileSize + 1
        
        // Draw tiled beagle wireframes
        for x in 0..<tilesX {
            for y in 0..<tilesY {
                let tileX = CGFloat(x * tileSize)
                let tileY = CGFloat(y * tileSize)
                
                // Translate to tile position
                context.saveGState()
                context.translateBy(x: tileX, y: tileY)
                
                // Draw wireframe beagle
                drawWireframeBeagle(in: context, size: CGFloat(tileSize))
                
                context.restoreGState()
            }
        }
    }
    
    private func drawWireframeBeagle(in context: CGContext, size: CGFloat) {
        let scale = size / 150.0 // Base size of 150px
        
        // Beagle head (circle)
        let headRadius = 30 * scale
        let headCenter = CGPoint(x: 75 * scale, y: 100 * scale)
        context.addEllipse(in: CGRect(
            x: headCenter.x - headRadius,
            y: headCenter.y - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        ))
        context.strokePath()
        
        // Beagle ears (two ovals)
        // Left ear
        context.addEllipse(in: CGRect(
            x: 35 * scale,
            y: 110 * scale,
            width: 20 * scale,
            height: 35 * scale
        ))
        context.strokePath()
        
        // Right ear
        context.addEllipse(in: CGRect(
            x: 95 * scale,
            y: 110 * scale,
            width: 20 * scale,
            height: 35 * scale
        ))
        context.strokePath()
        
        // Snout (smaller oval)
        context.addEllipse(in: CGRect(
            x: 65 * scale,
            y: 75 * scale,
            width: 20 * scale,
            height: 15 * scale
        ))
        context.strokePath()
        
        // Eyes (two small circles)
        context.addEllipse(in: CGRect(
            x: 60 * scale,
            y: 105 * scale,
            width: 6 * scale,
            height: 6 * scale
        ))
        context.strokePath()
        
        context.addEllipse(in: CGRect(
            x: 84 * scale,
            y: 105 * scale,
            width: 6 * scale,
            height: 6 * scale
        ))
        context.strokePath()
        
        // Nose (small triangle)
        context.move(to: CGPoint(x: 75 * scale, y: 85 * scale))
        context.addLine(to: CGPoint(x: 72 * scale, y: 78 * scale))
        context.addLine(to: CGPoint(x: 78 * scale, y: 78 * scale))
        context.closePath()
        context.strokePath()
        
        // Body (oval)
        context.addEllipse(in: CGRect(
            x: 55 * scale,
            y: 30 * scale,
            width: 40 * scale,
            height: 60 * scale
        ))
        context.strokePath()
        
        // Legs (four lines)
        // Front left leg
        context.move(to: CGPoint(x: 60 * scale, y: 40 * scale))
        context.addLine(to: CGPoint(x: 55 * scale, y: 10 * scale))
        context.strokePath()
        
        // Front right leg
        context.move(to: CGPoint(x: 70 * scale, y: 40 * scale))
        context.addLine(to: CGPoint(x: 75 * scale, y: 10 * scale))
        context.strokePath()
        
        // Back left leg
        context.move(to: CGPoint(x: 80 * scale, y: 35 * scale))
        context.addLine(to: CGPoint(x: 85 * scale, y: 10 * scale))
        context.strokePath()
        
        // Back right leg
        context.move(to: CGPoint(x: 90 * scale, y: 35 * scale))
        context.addLine(to: CGPoint(x: 95 * scale, y: 10 * scale))
        context.strokePath()
        
        // Tail (curved line)
        context.move(to: CGPoint(x: 95 * scale, y: 60 * scale))
        context.addCurve(
            to: CGPoint(x: 115 * scale, y: 80 * scale),
            control1: CGPoint(x: 105 * scale, y: 65 * scale),
            control2: CGPoint(x: 110 * scale, y: 75 * scale)
        )
        context.strokePath()
        
        // User name text label
        let text = userName.uppercased()
        let textSize = 7 * scale  // Slightly smaller to fit longer names
        let font = NSFont.systemFont(ofSize: textSize)
        let adaptiveColor = getAdaptiveColor()
        let alphaComponent = opacity / 100.0
        let attributes = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: adaptiveColor.withAlphaComponent(alphaComponent)
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // Calculate text size to center it properly
        let textBounds = attributedString.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: textSize + 2), options: [])
        let textWidth = textBounds.width
        
        let textRect = CGRect(
            x: (size - textWidth) / 2,  // Center horizontally
            y: 5 * scale,
            width: textWidth,
            height: textSize + 2
        )
        
        attributedString.draw(in: textRect)
    }
    
    private func getAdaptiveColor() -> NSColor {
        // Sample desktop background color
        let desktopColor = sampleDesktopBackgroundColor()
        
        // Calculate brightness of the desktop color
        let brightness = calculateBrightness(desktopColor)
        
        // Create adaptive color that's a couple shades different
        if brightness > 0.5 {
            // Light background - use darker color
            return desktopColor.adjustedBrightness(-0.3) // 30% darker
        } else {
            // Dark background - use lighter color
            return desktopColor.adjustedBrightness(0.3) // 30% lighter
        }
    }
    
    private func sampleDesktopBackgroundColor() -> NSColor {
        // Try to get the current desktop wallpaper's dominant color
        // For now, we'll use a simplified approach and sample from the screen
        
        // Sample multiple points across the screen to get average color
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0
        let sampleCount = 16
        
        // Sample points in a grid pattern
        for i in 0..<4 {
            for j in 0..<4 {
                let x = screenFrame.width * CGFloat(i) / 3.0
                let y = screenFrame.height * CGFloat(j) / 3.0
                let point = CGPoint(x: x, y: y)
                
                if let color = sampleColorAtPoint(point) {
                    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                    totalRed += red
                    totalGreen += green
                    totalBlue += blue
                }
            }
        }
        
        // Return average color
        return NSColor(
            red: totalRed / CGFloat(sampleCount),
            green: totalGreen / CGFloat(sampleCount),
            blue: totalBlue / CGFloat(sampleCount),
            alpha: 1.0
        )
    }
    
    private func sampleColorAtPoint(_ point: CGPoint) -> NSColor? {
        // Simplified: return a reasonable default based on system appearance
        if NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            // Dark mode - typical dark background
            return NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        } else {
            // Light mode - typical light background
            return NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        }
    }
    
    private func calculateBrightness(_ color: NSColor) -> CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Calculate perceived brightness using standard formula
        return (red * 0.299) + (green * 0.587) + (blue * 0.114)
    }
}

extension NSColor {
    func adjustedBrightness(_ adjustment: CGFloat) -> NSColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Adjust each component, clamping to 0-1 range
        let newRed = max(0, min(1, red + adjustment))
        let newGreen = max(0, min(1, green + adjustment))
        let newBlue = max(0, min(1, blue + adjustment))
        
        return NSColor(red: newRed, green: newGreen, blue: newBlue, alpha: alpha)
    }
}