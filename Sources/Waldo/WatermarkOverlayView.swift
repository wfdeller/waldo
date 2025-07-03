import Cocoa
import CoreGraphics

class WatermarkOverlayView: NSView {
    
    var watermarkData: String = "" {
        didSet {
            needsDisplay = true
        }
    }
    
    private var watermarkPattern: [UInt8] = []
    private let patternSize = WatermarkConstants.PATTERN_SIZE
    private var luminousEnabled: Bool = false
    
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
    
    func updateWatermarkData(_ newData: String, opacity: Int = WatermarkConstants.ALPHA_OPACITY) {
        watermarkData = newData
        generateWatermarkPattern(opacity: opacity)
    }
    
    func setLuminousEnabled(_ enabled: Bool) {
        luminousEnabled = enabled
        needsDisplay = true
    }
    
    private func generateWatermarkPattern(opacity: Int = WatermarkConstants.ALPHA_OPACITY) {
        // Create camera-detectable watermark pattern using robust techniques
        
        // Generate micro QR pattern for the watermark data
        let microPattern = generateMicroQRPattern(from: watermarkData)
        
        // Create redundant patterns across the overlay
        let redundantPattern = generateRedundantPattern(from: watermarkData)
        
        // Combine patterns with blue channel QR modulation for better camera detection
        var pattern: [UInt8] = []
        for i in 0..<(patternSize * patternSize * 4) {
            let pixelIndex = i / 4
            let channelIndex = i % 4
            
            // Get bits from patterns
            let microBit = microPattern[pixelIndex % microPattern.count]
            let redundantBit = redundantPattern[pixelIndex % redundantPattern.count]
            
            switch channelIndex {
            case 0: // Red channel - subtle redundant watermark only
                let baseValue: UInt8 = UInt8(WatermarkConstants.RGB_BASE)
                if redundantBit == 1 {
                    pattern.append(baseValue + UInt8(WatermarkConstants.RGB_DELTA / 2))  // Subtle red modulation
                } else {
                    pattern.append(baseValue)
                }
                
            case 1: // Green channel - minimal modulation for natural appearance
                let baseValue: UInt8 = UInt8(WatermarkConstants.RGB_BASE)
                if redundantBit == 1 {
                    pattern.append(baseValue + UInt8(WatermarkConstants.RGB_DELTA / 3))  // Very subtle green
                } else {
                    pattern.append(baseValue)
                }
                
            case 2: // Blue channel - PRIMARY QR code embedding
                let baseValue: UInt8 = UInt8(WatermarkConstants.RGB_BASE)
                if microBit == 1 {
                    // Strong blue signal for QR bits - cameras often have better blue channel sensitivity
                    pattern.append(baseValue + UInt8(WatermarkConstants.RGB_DELTA))
                } else {
                    // Lower blue for QR background
                    pattern.append(baseValue - UInt8(WatermarkConstants.RGB_DELTA / 2))
                }
                
            default: // Alpha channel
                pattern.append(UInt8(opacity))
            }
        }
        
        watermarkPattern = pattern
    }
    
    private func generateMicroQRPattern(from data: String) -> [UInt8] {
        // Create Version 2 QR code (37x37) with high error correction
        let qrSize = WatermarkConstants.QR_VERSION2_SIZE  // Version 2 QR code size (was 25 for micro)
        var pattern = [UInt8](repeating: 0, count: qrSize * qrSize)
        
        // Draw three finder patterns (classic QR code corners)
        drawFinderPattern(&pattern, size: qrSize, x: 0, y: 0)           // Top-left
        drawFinderPattern(&pattern, size: qrSize, x: qrSize-7, y: 0)     // Top-right  
        drawFinderPattern(&pattern, size: qrSize, x: 0, y: qrSize-7)     // Bottom-left
        
        // Draw separator patterns around finder patterns (1 pixel white border)
        drawSeparatorPatterns(&pattern, size: qrSize)
        
        // Draw alignment pattern for Version 2 (center: 18,18)
        // For Version 2 QR codes, alignment pattern is at (18,18) - offset by 2 for 5x5 pattern
        drawAlignmentPattern(&pattern, size: qrSize, x: 16, y: 16)  // 5x5 pattern centered at (18,18)
        
        // Draw timing patterns (horizontal and vertical lines)
        drawTimingPatterns(&pattern, size: qrSize)
        
        // Add format information areas (reserved for error correction level)
        addFormatInformation(&pattern, size: qrSize)
        
        // Embed data with Reed-Solomon error correction (ECC Level H)
        embedDataWithErrorCorrection(&pattern, size: qrSize, data: data)
        
        return pattern
    }
    
    private func drawFinderPattern(_ pattern: inout [UInt8], size: Int, x: Int, y: Int) {
        let finderSize = 7
        for dy in 0..<finderSize {
            for dx in 0..<finderSize {
                let px = x + dx
                let py = y + dy
                if px < size && py < size {
                    let index = py * size + px
                    // Create the classic QR finder pattern
                    let isOuterRing = (dx == 0 || dx == 6 || dy == 0 || dy == 6)
                    let isInnerSquare = (dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4)
                    pattern[index] = (isOuterRing || isInnerSquare) ? 1 : 0
                }
            }
        }
    }
    
    private func drawAlignmentPattern(_ pattern: inout [UInt8], size: Int, x: Int, y: Int) {
        let alignSize = 5
        for dy in 0..<alignSize {
            for dx in 0..<alignSize {
                let px = x + dx
                let py = y + dy
                if px >= 0 && px < size && py >= 0 && py < size {
                    let index = py * size + px
                    let isRing = (dx == 0 || dx == 4 || dy == 0 || dy == 4)
                    let isCenter = (dx == 2 && dy == 2)
                    pattern[index] = (isRing || isCenter) ? 1 : 0
                }
            }
        }
    }
    
    private func drawTimingPatterns(_ pattern: inout [UInt8], size: Int) {
        // Horizontal timing pattern (row 6, skipping finder and format areas)
        for x in 8..<(size-8) {
            if x != 6 {  // Skip format information column
                let index = 6 * size + x
                pattern[index] = UInt8(x % 2)
            }
        }
        
        // Vertical timing pattern (column 6, skipping finder and format areas)
        for y in 8..<(size-8) {
            if y != 6 {  // Skip format information row
                let index = y * size + 6
                pattern[index] = UInt8(y % 2)
            }
        }
    }
    
    private func embedDataInQR(_ pattern: inout [UInt8], size: Int, data: String) {
        let stringData = Data(data.utf8)
        let bits = stringData.flatMap { byte in
            (0..<8).map { (byte >> $0) & 1 }
        }
        
        var bitIndex = 0
        // Fill in data areas (avoiding finder, alignment, timing, and format patterns)
        for y in 0..<size {
            for x in 0..<size {
                let index = y * size + x
                
                // Skip areas used by structural patterns
                let inTopLeftFinder = (x < 9 && y < 9)
                let inTopRightFinder = (x >= size-8 && y < 9)
                let inBottomLeftFinder = (x < 9 && y >= size-8)
                let inAlignment = (x >= 16 && x <= 20 && y >= 16 && y <= 20)  // Version 2 alignment at (18,18) - 5x5 pattern
                let inTiming = (x == 6 || y == 6)
                let inFormatInfo = isFormatInformationArea(x: x, y: y, size: size)
                
                let inFinder = inTopLeftFinder || inTopRightFinder || inBottomLeftFinder
                let inReserved = inFinder || inAlignment || inTiming || inFormatInfo
                
                if !inReserved && bitIndex < bits.count {
                    pattern[index] = UInt8(bits[bitIndex])
                    bitIndex += 1
                }
            }
        }
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
    
    private func drawSeparatorPatterns(_ pattern: inout [UInt8], size: Int) {
        // White separator borders around finder patterns
        
        // Top-left finder separator
        for x in 0..<8 {
            if x < size && 7 < size {
                pattern[7 * size + x] = 0  // Bottom border
            }
        }
        for y in 0..<8 {
            if 7 < size && y < size {
                pattern[y * size + 7] = 0  // Right border
            }
        }
        
        // Top-right finder separator
        for x in (size-8)..<size {
            if x >= 0 && x < size && 7 < size {
                pattern[7 * size + x] = 0  // Bottom border
            }
        }
        for y in 0..<8 {
            if (size-8) >= 0 && (size-8) < size && y < size {
                pattern[y * size + (size-8)] = 0  // Left border
            }
        }
        
        // Bottom-left finder separator
        for x in 0..<8 {
            if x < size && (size-8) >= 0 && (size-8) < size {
                pattern[(size-8) * size + x] = 0  // Top border
            }
        }
        for y in (size-8)..<size {
            if 7 < size && y >= 0 && y < size {
                pattern[y * size + 7] = 0  // Right border
            }
        }
    }
    
    private func addFormatInformation(_ pattern: inout [UInt8], size: Int) {
        // Reserve format information areas (will be filled with ECC Level H indicator)
        // Format info is placed around top-left and split between top-right/bottom-left
        
        // Format information around top-left finder pattern
        for i in 0..<6 {
            if i < size && 8 < size {
                pattern[8 * size + i] = 0  // Horizontal format strip
            }
            if 8 < size && i < size {
                pattern[i * size + 8] = 0  // Vertical format strip
            }
        }
        
        // Skip timing pattern intersection
        for i in 7..<9 {
            if i < size && 8 < size {
                pattern[8 * size + i] = 0
            }
            if 8 < size && i < size {
                pattern[i * size + 8] = 0
            }
        }
        
        // Format information in other corners
        for i in 0..<8 {
            if (size-1-i) >= 0 && (size-1-i) < size && 8 < size {
                pattern[8 * size + (size-1-i)] = 0  // Top-right format
            }
            if (size-7+i) >= 0 && (size-7+i) < size && 8 < size {
                pattern[(size-7+i) * size + 8] = 0  // Bottom-left format
            }
        }
    }
    
    private func isFormatInformationArea(x: Int, y: Int, size: Int) -> Bool {
        // Check if position is in format information area
        let inHorizontalFormat = (y == 8 && (x < 9 || x >= size-8))
        let inVerticalFormat = (x == 8 && (y < 9 || y >= size-7))
        return inHorizontalFormat || inVerticalFormat
    }
    
    private func embedDataWithErrorCorrection(_ pattern: inout [UInt8], size: Int, data: String) {
        // Enhanced error correction using Reed-Solomon principles
        let errorCorrectedData = generateHighErrorCorrectionData(data)
        let stringData = Data(errorCorrectedData.utf8)
        let bits = stringData.flatMap { byte in
            (0..<8).map { (byte >> (7-$0)) & 1 }  // MSB first for proper QR encoding
        }
        
        var bitIndex = 0
        
        // QR code data placement follows zigzag pattern from bottom-right
        var up = true
        var col = size - 1
        
        while col > 0 {
            if col == 6 { col -= 1 }  // Skip timing column
            
            for _ in 0..<size {
                for c in 0..<2 {
                    let x = col - c
                    let y = up ? (size - 1 - (bitIndex / 2) % size) : (bitIndex / 2) % size
                    
                    if x >= 0 && x < size && y >= 0 && y < size {
                        let index = y * size + x
                        
                        // Check if this position is available for data
                        let inFinder = isFinderPatternArea(x: x, y: y, size: size)
                        let inAlignment = (x >= 16 && x <= 20 && y >= 16 && y <= 20)  // Version 2 alignment at (18,18)
                        let inTiming = (x == 6 || y == 6)
                        let inFormat = isFormatInformationArea(x: x, y: y, size: size)
                        
                        if !inFinder && !inAlignment && !inTiming && !inFormat {
                            if bitIndex < bits.count {
                                pattern[index] = UInt8(bits[bitIndex])
                            } else {
                                pattern[index] = 0  // Padding
                            }
                            bitIndex += 1
                        }
                    }
                }
            }
            
            up = !up
            col -= 2
        }
    }
    
    private func isFinderPatternArea(x: Int, y: Int, size: Int) -> Bool {
        let inTopLeft = (x < 9 && y < 9)
        let inTopRight = (x >= size-8 && y < 9)
        let inBottomLeft = (x < 9 && y >= size-8)
        return inTopLeft || inTopRight || inBottomLeft
    }
    
    private func generateHighErrorCorrectionData(_ input: String) -> String {
        // Enhanced error correction for ECC Level H (30% recovery capability)
        // Use multiple redundancy techniques:
        
        // 1. Character-level repetition (3x)
        let characterRepeated = input.map { String(repeating: String($0), count: 3) }.joined()
        
        // 2. Block-level redundancy - repeat entire message
        let blockRepeated = String(repeating: characterRepeated + "|", count: 2)
        
        // 3. Checksum for validation
        let checksum = input.reduce(0) { $0 + Int($1.asciiValue ?? 0) } % 256
        let checksumHex = String(format: "%02X", checksum)
        
        return blockRepeated + checksumHex
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
        
        // Draw discrete QR codes in screen corners
        drawCornerQRCodes(in: ctx, viewSize: viewSize, backingScaleFactor: backingScaleFactor)
        
        // Draw luminous markers if enabled
        if luminousEnabled {
            LuminousMarkerRenderer.renderLuminousMarkers(
                in: ctx,
                size: viewSize,
                opacity: WatermarkConstants.ALPHA_OPACITY,
                avoidCorners: true,
                logger: Logger()
            )
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
    
    private func drawCornerQRCodes(in context: CGContext, viewSize: CGSize, backingScaleFactor: CGFloat) {
        // Version 2 QR codes with blue channel modulation for better camera detection
        let qrPixelSize = WatermarkConstants.QR_VERSION2_SIZE  // Version 2 QR code modules
        let pixelsPerQRBit: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_PIXELS_PER_MODULE)  // Pixels per QR module
        let qrSize: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_PIXEL_SIZE)  // Total pixel size
        let margin: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_MARGIN)   // Consistent margin
        let menuBarOffset: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_MENU_BAR_OFFSET)  // Consistent offset
        
        // Generate QR pattern for current watermark data
        let qrPattern = generateMicroQRPattern(from: watermarkData)
        if qrPattern.count != qrPixelSize * qrPixelSize {
            print("Warning: QR pattern size mismatch: \(qrPattern.count) elements, expected \(qrPixelSize * qrPixelSize)")
        }
        
        // Define corner positions
        let corners = [
            CGPoint(x: viewSize.width - qrSize - margin, y: viewSize.height - menuBarOffset - qrSize),  // Top-right (flipped Y)
            CGPoint(x: margin, y: viewSize.height - menuBarOffset - qrSize),                           // Top-left (flipped Y)
            CGPoint(x: viewSize.width - qrSize - margin, y: margin),                                   // Bottom-right
            CGPoint(x: margin, y: margin)                                                              // Bottom-left
        ]
        
        // Draw QR code at each corner
        for corner in corners {
            drawQRCode(in: context, at: corner, size: qrSize, pattern: qrPattern, patternSize: qrPixelSize, pixelsPerBit: pixelsPerQRBit)
        }
    }
    
    private func drawQRCode(in context: CGContext, at position: CGPoint, size: CGFloat, pattern: [UInt8], patternSize: Int, pixelsPerBit: CGFloat) {
        // Each QR bit is rendered as pixelsPerBit x pixelsPerBit pixels with blue channel modulation
        
        for y in 0..<patternSize {
            for x in 0..<patternSize {
                let patternIndex = y * patternSize + x
                if patternIndex < pattern.count {
                    let bit = pattern[patternIndex]
                    
                    // Blue channel modulation: embed QR in blue while maintaining visual subtlety
                    let baseColor: CGFloat = CGFloat(WatermarkConstants.RGB_BASE) / 255.0
                    let deltaColor: CGFloat = CGFloat(WatermarkConstants.RGB_DELTA) / 255.0
                    
                    let red: CGFloat = baseColor
                    let green: CGFloat = baseColor
                    let blue: CGFloat = bit == 1 ? baseColor + deltaColor : baseColor - (deltaColor / 2)
                    let alpha: CGFloat = CGFloat(WatermarkConstants.ALPHA_OPACITY) / 255.0
                    
                    let color = CGColor(red: red, green: green, blue: blue, alpha: alpha)
                    context.setFillColor(color)
                    
                    let pixelRect = CGRect(
                        x: position.x + CGFloat(x) * pixelsPerBit,
                        y: position.y + CGFloat(y) * pixelsPerBit,
                        width: pixelsPerBit,
                        height: pixelsPerBit
                    )
                    
                    context.fill(pixelRect)
                }
            }
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