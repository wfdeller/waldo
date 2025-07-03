import Foundation
import CoreGraphics
import Cocoa

class LuminousOverlayRenderer: OverlayRenderer {
    let overlayType: OverlayType = .luminous
    private var currentPattern: LuminousOverlayConstants.LuminancePattern = .uniform
    private var timer: Timer?
    
    func createOverlayView(frame: CGRect, opacity: Int, luminous: Bool, logger: Logger) -> NSView? {
        logger.debug("Creating luminous overlay view with frame: \(frame), luminous: \(luminous)")
        let luminousView = LuminousOverlayView(frame: frame, pattern: currentPattern)
        luminousView.updateOpacity(opacity)
        // For standalone luminous overlay, always render markers regardless of luminous flag
        return luminousView
    }
    
    func renderOverlayImage(size: CGSize, opacity: Int, luminous: Bool, logger: Logger) -> CGImage? {
        logger.debug("Rendering luminous overlay image with size: \(size), luminous: \(luminous)")
        
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
            logger.debug("Failed to create bitmap context for luminous overlay")
            return nil
        }
        
        context.clear(CGRect(origin: .zero, size: size))
        
        // For standalone luminous overlay, always render corner markers
        LuminousMarkerRenderer.renderLuminousMarkers(
            in: context,
            size: size,
            opacity: opacity,
            logger: logger
        )
        
        return context.makeImage()
    }
    
    func setPattern(_ pattern: LuminousOverlayConstants.LuminancePattern) {
        currentPattern = pattern
    }
    
    func renderLuminousPattern(in context: CGContext, size: CGSize, pattern: LuminousOverlayConstants.LuminancePattern, opacity: Int, time: Double, logger: Logger) {
        let patternSize = LuminousOverlayConstants.PATTERN_SIZE
        let tileSize = LuminousOverlayConstants.PATTERN_TILE_SIZE
        
        let tilesX = Int(ceil(size.width / CGFloat(tileSize)))
        let tilesY = Int(ceil(size.height / CGFloat(tileSize)))
        
        logger.debug("Drawing \(tilesX)x\(tilesY) luminous tiles with pattern: \(pattern)")
        
        for tileY in 0..<tilesY {
            for tileX in 0..<tilesX {
                let tileRect = CGRect(
                    x: CGFloat(tileX * tileSize),
                    y: CGFloat(tileY * tileSize),
                    width: CGFloat(tileSize),
                    height: CGFloat(tileSize)
                )
                
                renderLuminousTile(
                    in: context,
                    rect: tileRect,
                    pattern: pattern,
                    opacity: opacity,
                    time: time
                )
            }
        }
        
        // Add corner luminance markers for detection
        renderCornerMarkers(in: context, size: size, opacity: opacity, logger: logger)
    }
    
    private func renderLuminousTile(in context: CGContext, rect: CGRect, pattern: LuminousOverlayConstants.LuminancePattern, opacity: Int, time: Double) {
        let patternSize = LuminousOverlayConstants.PATTERN_SIZE
        let pixelWidth = rect.width / CGFloat(patternSize)
        let pixelHeight = rect.height / CGFloat(patternSize)
        
        for y in 0..<patternSize {
            for x in 0..<patternSize {
                let luminance = LuminousOverlayConstants.getLuminanceForPattern(pattern, x: x, y: y, time: time)
                
                // Convert luminance to RGB values
                let red = luminance
                let green = luminance
                let blue = luminance
                let alpha = CGFloat(opacity) / 255.0
                
                let color = CGColor(red: red, green: green, blue: blue, alpha: alpha)
                context.setFillColor(color)
                
                let pixelRect = CGRect(
                    x: rect.origin.x + CGFloat(x) * pixelWidth,
                    y: rect.origin.y + CGFloat(y) * pixelHeight,
                    width: pixelWidth,
                    height: pixelHeight
                )
                
                context.fill(pixelRect)
            }
        }
    }
    
    private func renderCornerMarkers(in context: CGContext, size: CGSize, opacity: Int, logger: Logger) {
        let markerSize = LuminousOverlayConstants.CORNER_PATTERN_SIZE
        let margin = size.width * LuminousOverlayConstants.MARGIN_PERCENTAGE
        
        let corners = [
            CGPoint(x: margin, y: margin),
            CGPoint(x: size.width - markerSize - margin, y: margin),
            CGPoint(x: margin, y: size.height - markerSize - margin),
            CGPoint(x: size.width - markerSize - margin, y: size.height - markerSize - margin)
        ]
        
        for corner in corners {
            renderLuminanceMarker(
                in: context,
                at: corner,
                size: markerSize,
                opacity: opacity
            )
        }
        
        logger.debug("Rendered luminance markers at \(corners.count) corners")
    }
    
    private func renderLuminanceMarker(in context: CGContext, at position: CGPoint, size: CGFloat, opacity: Int) {
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
    
    func startTemporalPattern() {
        guard LuminousOverlayConstants.ENABLE_TEMPORAL_PATTERNS else { return }
        
        let interval = 1.0 / LuminousOverlayConstants.FLICKER_FREQUENCY_HZ
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateTemporalPattern()
        }
    }
    
    func stopTemporalPattern() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTemporalPattern() {
        // Trigger redraw for temporal patterns
        // This would be handled by the view's display link or timer
    }
    
    deinit {
        stopTemporalPattern()
    }
}

class LuminousOverlayView: NSView {
    private var pattern: LuminousOverlayConstants.LuminancePattern
    private var opacity: Int = WatermarkConstants.ALPHA_OPACITY
    private var displayLink: CVDisplayLink?
    private var renderer: LuminousOverlayRenderer
    
    init(frame frameRect: NSRect, pattern: LuminousOverlayConstants.LuminancePattern = .uniform) {
        self.pattern = pattern
        self.renderer = LuminousOverlayRenderer()
        super.init(frame: frameRect)
        setupView()
        setupDisplayLink()
    }
    
    required init?(coder: NSCoder) {
        self.pattern = .uniform
        self.renderer = LuminousOverlayRenderer()
        super.init(coder: coder)
        setupView()
        setupDisplayLink()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    private func setupDisplayLink() {
        guard LuminousOverlayConstants.ENABLE_TEMPORAL_PATTERNS else { return }
        
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        if let displayLink = displayLink {
            CVDisplayLinkSetOutputCallback(displayLink, { _, _, _, _, _, context in
                let view = Unmanaged<LuminousOverlayView>.fromOpaque(context!).takeUnretainedValue()
                DispatchQueue.main.async {
                    view.needsDisplay = true
                }
                return kCVReturnSuccess
            }, Unmanaged.passUnretained(self).toOpaque())
            CVDisplayLinkStart(displayLink)
        }
    }
    
    func updateOpacity(_ newOpacity: Int) {
        opacity = newOpacity
        needsDisplay = true
    }
    
    func updatePattern(_ newPattern: LuminousOverlayConstants.LuminancePattern) {
        pattern = newPattern
        renderer.setPattern(newPattern)
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Use the shared luminous marker renderer
        LuminousMarkerRenderer.renderLuminousMarkers(
            in: context,
            size: bounds.size,
            opacity: opacity,
            logger: Logger()
        )
    }
    
    override var isOpaque: Bool { return false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { return false }
    override func hitTest(_ point: NSPoint) -> NSView? { return nil }
    
    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
}