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
        // Create camera-detectable watermark pattern using robust techniques
        
        // Generate micro QR pattern for the watermark data
        let microPattern = generateMicroQRPattern(from: watermarkData)
        
        // Create redundant patterns across the overlay
        let redundantPattern = generateRedundantPattern(from: watermarkData)
        
        // Combine patterns with very subtle visibility for camera detection
        var pattern: [UInt8] = []
        for i in 0..<(patternSize * patternSize * 4) {
            let pixelIndex = i / 4
            
            if i % 4 < 3 {
                // RGB channels: embed camera-detectable patterns
                let baseValue: UInt8 = 128
                
                // Get bits from micro QR pattern
                let microBit = microPattern[pixelIndex % microPattern.count]
                
                // Get bits from redundant pattern  
                let redundantBit = redundantPattern[pixelIndex % redundantPattern.count]
                
                // Combine patterns with more visible modifications for testing (±10 levels)
                let modification: UInt8 = (microBit == 1 || redundantBit == 1) ? 10 : 0
                pattern.append(baseValue + modification)
            } else {
                // Alpha channel: more visible for testing
                pattern.append(25)  // More visible for camera detection testing
            }
        }
        
        watermarkPattern = pattern
    }
    
    private func generateMicroQRPattern(from data: String) -> [UInt8] {
        // Create a simple 2D barcode pattern
        let stringData = Data(data.utf8)
        let bits = stringData.flatMap { byte in
            (0..<8).map { (byte >> $0) & 1 }
        }
        
        var pattern = [UInt8](repeating: 0, count: patternSize * patternSize)
        
        // Embed length in first 16 positions
        let length = UInt16(bits.count)
        for i in 0..<min(16, pattern.count) {
            pattern[i] = UInt8((length >> i) & 1)
        }
        
        // Embed data bits with repetition for robustness
        for (index, bit) in bits.enumerated() {
            let position = (index % (pattern.count - 16)) + 16
            pattern[position] = UInt8(bit)
        }
        
        return pattern
    }
    
    private func generateRedundantPattern(from data: String) -> [UInt8] {
        // Create redundant encoding with error correction
        let errorCorrectedData = addSimpleErrorCorrection(data)
        let stringData = Data(errorCorrectedData.utf8)
        let bits = stringData.flatMap { byte in
            (0..<8).map { (byte >> $0) & 1 }
        }
        
        var pattern = [UInt8](repeating: 0, count: patternSize * patternSize)
        
        // Repeat the pattern multiple times across the overlay
        for i in 0..<pattern.count {
            pattern[i] = UInt8(bits[i % bits.count])
        }
        
        return pattern
    }
    
    private func addSimpleErrorCorrection(_ input: String) -> String {
        // Simple repetition code - repeat each character 3 times for error correction
        return input.map { String(repeating: String($0), count: 3) }.joined()
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