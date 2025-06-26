import Cocoa
import CoreGraphics

class WatermarkOverlayView: NSView {
    var watermarkData: String = "" {
        didSet {
            needsDisplay = true
        }
    }
    
    private var watermarkPattern: [UInt8] = []
    private let patternSize = 64
    
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
    
    func updateWatermarkData(_ newData: String) {
        watermarkData = newData
        generateWatermarkPattern()
    }
    
    private func generateWatermarkPattern() {
        let data = Data(watermarkData.utf8)
        let watermarkBits = data.flatMap { byte in
            (0..<8).map { (byte >> $0) & 1 }
        }
        
        let lengthBits = withUnsafeBytes(of: UInt32(watermarkBits.count).bigEndian) { bytes in
            bytes.flatMap { byte in
                (0..<8).map { (byte >> $0) & 1 }
            }
        }
        
        let allBits = lengthBits + watermarkBits
        
        var pattern: [UInt8] = []
        for i in 0..<(patternSize * patternSize * 4) {
            if i % 4 < 3 {
                // RGB channels: use base value without watermark data to avoid conflicts
                pattern.append(128)
            } else {
                // Alpha channel: embed watermark data here (steganography uses RGB only)
                let bitIndex = (i / 4) % allBits.count
                let bit = allBits[bitIndex]
                let baseAlpha: UInt8 = 2  // Barely visible
                pattern.append((baseAlpha & 0xFE) | UInt8(bit))
            }
        }
        
        watermarkPattern = pattern
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard !watermarkPattern.isEmpty else { return }
        
        let context = NSGraphicsContext.current?.cgContext
        guard let ctx = context else { return }
        
        // Get the backing scale factor for proper high-DPI rendering
        let backingScaleFactor = window?.backingScaleFactor ?? 1.0
        let viewSize = bounds.size
        
        // Adjust pattern size based on backing scale factor for consistent watermark density
        let effectivePatternSize = CGFloat(patternSize) / backingScaleFactor
        let patternCGSize = CGSize(width: effectivePatternSize, height: effectivePatternSize)
        
        let tilesX = Int(ceil(viewSize.width / patternCGSize.width))
        let tilesY = Int(ceil(viewSize.height / patternCGSize.height))
        
        for tileY in 0..<tilesY {
            for tileX in 0..<tilesX {
                let tileRect = CGRect(
                    x: CGFloat(tileX) * patternCGSize.width,
                    y: CGFloat(tileY) * patternCGSize.height,
                    width: patternCGSize.width,
                    height: patternCGSize.height
                )
                
                drawWatermarkTile(in: ctx, rect: tileRect)
            }
        }
    }
    
    private func drawWatermarkTile(in context: CGContext, rect: CGRect) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = patternSize * bytesPerPixel
        
        watermarkPattern.withUnsafeBytes { bytes in
            guard let cgContext = CGContext(
                data: UnsafeMutableRawPointer(mutating: bytes.baseAddress),
                width: patternSize,
                height: patternSize,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            
            guard let image = cgContext.makeImage() else { return }
            
            context.draw(image, in: rect)
        }
    }
    
    override var isOpaque: Bool {
        return false
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return false
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}