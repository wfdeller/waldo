import Foundation
import CoreGraphics
import Cocoa

class QROverlayRenderer: DataEmbeddingRenderer {
    let overlayType: OverlayType = .qr
    
    func createOverlayView(frame: CGRect, opacity: Int, luminous: Bool, watermarkData: String, logger: Logger) -> NSView? {
        logger.debug("Creating QR overlay view with frame: \(frame), luminous: \(luminous)")
        let qrView = QROverlayView(frame: frame)
        qrView.updateWatermarkData(watermarkData, opacity: opacity, luminous: luminous)
        return qrView
    }
    
    func renderOverlayImage(size: CGSize, opacity: Int, luminous: Bool, watermarkData: String, logger: Logger) -> CGImage? {
        logger.debug("Rendering QR overlay image with size: \(size), luminous: \(luminous)")
        
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
            logger.debug("Failed to create bitmap context for QR overlay")
            return nil
        }
        
        context.clear(CGRect(origin: .zero, size: size))
        
        drawCornerQRCodes(
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
    
    func drawCornerQRCodes(in context: CGContext, watermarkData: String, viewSize: CGSize, opacity: Int, logger: Logger) {
        let qrPixelSize = WatermarkConstants.QR_VERSION2_SIZE
        let pixelsPerQRBit: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_PIXELS_PER_MODULE)
        let qrSize: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_PIXEL_SIZE)
        let margin: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_MARGIN)
        let menuBarOffset: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_MENU_BAR_OFFSET)
        
        let qrPattern = generateMicroQRPattern(from: watermarkData)
        if qrPattern.count != qrPixelSize * qrPixelSize {
            logger.debug("Warning: QR pattern size mismatch: \(qrPattern.count) elements, expected \(qrPixelSize * qrPixelSize)")
        }
        
        let corners = [
            CGPoint(x: viewSize.width - qrSize - margin, y: viewSize.height - menuBarOffset - qrSize),
            CGPoint(x: margin, y: viewSize.height - menuBarOffset - qrSize),
            CGPoint(x: viewSize.width - qrSize - margin, y: margin),
            CGPoint(x: margin, y: margin)
        ]
        
        logger.debug("Drawing QR codes at \(corners.count) corner positions")
        
        for corner in corners {
            drawQRCode(
                in: context,
                at: corner,
                size: qrSize,
                pattern: qrPattern,
                patternSize: qrPixelSize,
                pixelsPerBit: pixelsPerQRBit,
                opacity: opacity
            )
        }
    }
    
    private func drawQRCode(in context: CGContext, at position: CGPoint, size: CGFloat, pattern: [UInt8], patternSize: Int, pixelsPerBit: CGFloat, opacity: Int) {
        for y in 0..<patternSize {
            for x in 0..<patternSize {
                let patternIndex = y * patternSize + x
                if patternIndex < pattern.count {
                    let bit = pattern[patternIndex]
                    
                    let baseColor: CGFloat = CGFloat(WatermarkConstants.RGB_BASE) / 255.0
                    let deltaColor: CGFloat = CGFloat(WatermarkConstants.RGB_DELTA) / 255.0
                    
                    let red: CGFloat = baseColor
                    let green: CGFloat = baseColor
                    let blue: CGFloat = bit == 1 ? baseColor + deltaColor : baseColor - (deltaColor / 2)
                    let alpha: CGFloat = CGFloat(opacity) / 255.0
                    
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
    
    private func generateMicroQRPattern(from data: String) -> [UInt8] {
        let qrSize = WatermarkConstants.QR_VERSION2_SIZE
        var pattern = [UInt8](repeating: 0, count: qrSize * qrSize)
        
        drawFinderPattern(&pattern, size: qrSize, x: 0, y: 0)
        drawFinderPattern(&pattern, size: qrSize, x: qrSize-7, y: 0)
        drawFinderPattern(&pattern, size: qrSize, x: 0, y: qrSize-7)
        
        drawSeparatorPatterns(&pattern, size: qrSize)
        drawAlignmentPattern(&pattern, size: qrSize, x: 16, y: 16)
        drawTimingPatterns(&pattern, size: qrSize)
        addFormatInformation(&pattern, size: qrSize)
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
        for x in 8..<(size-8) {
            if x != 6 {
                let index = 6 * size + x
                pattern[index] = UInt8(x % 2)
            }
        }
        for y in 8..<(size-8) {
            if y != 6 {
                let index = y * size + 6
                pattern[index] = UInt8(y % 2)
            }
        }
    }
    
    private func drawSeparatorPatterns(_ pattern: inout [UInt8], size: Int) {
        for x in 0..<8 {
            if x < size && 7 < size {
                pattern[7 * size + x] = 0
            }
        }
        for y in 0..<8 {
            if 7 < size && y < size {
                pattern[y * size + 7] = 0
            }
        }
        for x in (size-8)..<size {
            if x >= 0 && x < size && 7 < size {
                pattern[7 * size + x] = 0
            }
        }
        for y in 0..<8 {
            if (size-8) >= 0 && (size-8) < size && y < size {
                pattern[y * size + (size-8)] = 0
            }
        }
        for x in 0..<8 {
            if x < size && (size-8) >= 0 && (size-8) < size {
                pattern[(size-8) * size + x] = 0
            }
        }
        for y in (size-8)..<size {
            if 7 < size && y >= 0 && y < size {
                pattern[y * size + 7] = 0
            }
        }
    }
    
    private func addFormatInformation(_ pattern: inout [UInt8], size: Int) {
        for i in 0..<6 {
            if i < size && 8 < size {
                pattern[8 * size + i] = 0
            }
            if 8 < size && i < size {
                pattern[i * size + 8] = 0
            }
        }
        for i in 7..<9 {
            if i < size && 8 < size {
                pattern[8 * size + i] = 0
            }
            if 8 < size && i < size {
                pattern[i * size + 8] = 0
            }
        }
        for i in 0..<8 {
            if (size-1-i) >= 0 && (size-1-i) < size && 8 < size {
                pattern[8 * size + (size-1-i)] = 0
            }
            if (size-7+i) >= 0 && (size-7+i) < size && 8 < size {
                pattern[(size-7+i) * size + 8] = 0
            }
        }
    }
    
    private func isFormatInformationArea(x: Int, y: Int, size: Int) -> Bool {
        let inHorizontalFormat = (y == 8 && (x < 9 || x >= size-8))
        let inVerticalFormat = (x == 8 && (y < 9 || y >= size-7))
        return inHorizontalFormat || inVerticalFormat
    }
    
    private func embedDataWithErrorCorrection(_ pattern: inout [UInt8], size: Int, data: String) {
        let errorCorrectedData = generateHighErrorCorrectionData(data)
        let stringData = Data(errorCorrectedData.utf8)
        let bits = stringData.flatMap { byte in
            (0..<8).map { (byte >> (7-$0)) & 1 }
        }
        
        var bitIndex = 0
        var up = true
        var col = size - 1
        
        while col > 0 {
            if col == 6 { col -= 1 }
            
            for _ in 0..<size {
                for c in 0..<2 {
                    let x = col - c
                    let y = up ? (size - 1 - (bitIndex / 2) % size) : (bitIndex / 2) % size
                    
                    if x >= 0 && x < size && y >= 0 && y < size {
                        let index = y * size + x
                        
                        let inFinder = isFinderPatternArea(x: x, y: y, size: size)
                        let inAlignment = (x >= 16 && x <= 20 && y >= 16 && y <= 20)
                        let inTiming = (x == 6 || y == 6)
                        let inFormat = isFormatInformationArea(x: x, y: y, size: size)
                        
                        if !inFinder && !inAlignment && !inTiming && !inFormat {
                            if bitIndex < bits.count {
                                pattern[index] = UInt8(bits[bitIndex])
                            } else {
                                pattern[index] = 0
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
        let characterRepeated = input.map { String(repeating: String($0), count: 3) }.joined()
        let blockRepeated = String(repeating: characterRepeated + "|", count: 2)
        let checksum = input.reduce(0) { $0 + Int($1.asciiValue ?? 0) } % 256
        let checksumHex = String(format: "%02X", checksum)
        return blockRepeated + checksumHex
    }
}

class QROverlayView: NSView {
    private var watermarkData: String = ""
    private var opacity: Int = WatermarkConstants.ALPHA_OPACITY
    private var luminous: Bool = false
    
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
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard !watermarkData.isEmpty,
              let context = NSGraphicsContext.current?.cgContext else { return }
        
        let renderer = QROverlayRenderer()
        renderer.drawCornerQRCodes(
            in: context,
            watermarkData: watermarkData,
            viewSize: bounds.size,
            opacity: opacity,
            logger: Logger()
        )
        
        if luminous {
            LuminousMarkerRenderer.renderLuminousMarkers(
                in: context,
                size: bounds.size,
                opacity: opacity,
                avoidCorners: true,
                logger: Logger()
            )
        }
    }
    
    override var isOpaque: Bool { return false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { return false }
    override func hitTest(_ point: NSPoint) -> NSView? { return nil }
}