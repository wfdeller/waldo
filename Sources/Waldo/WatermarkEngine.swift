import CoreGraphics
import Foundation
import Accelerate

class WatermarkEngine {
    
    
    // MARK: - Public Interface
    
    static func embedPhotoResistantWatermark(in image: CGImage, data: String) -> CGImage? {
        var result = image
        
        // 1. Redundant embedding with error correction (fast and effective)
        if let redundantResult = embedRedundantWatermark(result, watermark: data) {
            result = redundantResult
        }
        
        // 2. Micro QR pattern as backup (fast)
        if let qrResult = embedMicroQRPattern(result, watermark: data) {
            result = qrResult
        }
        
        // 3. Spread spectrum embedding (fast alternative to DCT)
        if let spreadResult = embedSpreadSpectrum(result, watermark: data) {
            result = spreadResult
        }
        
        return result
    }
    
    static func extractPhotoResistantWatermark(from image: CGImage) -> String? {
        // Try overlay-specific extraction first (for camera photos of screens)
        if let overlayResult = extractOverlayWatermark(from: image) {
            return overlayResult
        }
        
        // Try multiple extraction methods in order of robustness
        if let redundantResult = extractRedundantWatermark(from: image) { 
            return redundantResult 
        }
        
        if let qrResult = extractMicroQRPattern(from: image) { 
            return qrResult 
        }
        
        if let spreadResult = extractSpreadSpectrum(from: image) { 
            return spreadResult 
        }
        
        return nil
    }
    
    // MARK: - Overlay Watermark Extraction (for camera photos of screens)
    
    private static func extractOverlayWatermark(from image: CGImage) -> String? {
        guard let pixelData = extractPixelData(from: image) else { return nil }
        
        let width = image.width
        let height = image.height
        
        // Try different tile sizes (camera might scale the overlay)
        let tileSizes = [16, 32, 48, 64]
        
        // Sample multiple regions to find the strongest pattern
        var bestResult: String?
        var bestScore = 0.0
        
        for tileSize in tileSizes {
            // Try different positions across the image
            let samplePositions = [
                (x: width / 8, y: height / 8),
                (x: width / 4, y: height / 4),
                (x: width / 2, y: height / 2),
                (x: 3 * width / 4, y: height / 4),
                (x: width / 4, y: 3 * height / 4),
                (x: 3 * width / 4, y: 3 * height / 4),
                (x: 7 * width / 8, y: 7 * height / 8)
            ]
            
            for position in samplePositions {
                if let (result, score) = extractOverlayPatternAt(pixelData, width: width, height: height, 
                                                               startX: position.x, startY: position.y, tileSize: tileSize) {
                    if score > bestScore {
                        bestScore = score
                        bestResult = result
                    }
                }
            }
        }
        
        return bestScore > WatermarkConstants.PHOTO_CONFIDENCE_THRESHOLD ? bestResult : nil  
    }
    
    private static func extractOverlayPatternAt(_ pixelData: [UInt8], width: Int, height: Int, 
                                              startX: Int, startY: Int, tileSize: Int) -> (String, Double)? {
        var extractedBits: [UInt8] = []
        var confidence: Double = 0
        var sampleCount = 0
        
        // Extract pattern from a tile-sized region
        for y in 0..<tileSize {
            for x in 0..<tileSize {
                let pixelX = startX + x
                let pixelY = startY + y
                
                if pixelX < width && pixelY < height {
                    let pixelIndex = (pixelY * width + pixelX) * 4
                    
                    if pixelIndex + 2 < pixelData.count {
                        // Look for the subtle modifications in RGB channels
                        let r = pixelData[pixelIndex]
                        let g = pixelData[pixelIndex + 1] 
                        let b = pixelData[pixelIndex + 2]
                        
                        // For camera photos, we need to be more adaptive about the baseline
                        // Calculate local average as baseline (camera color shifts)
                        var localR = 0, localG = 0, localB = 0, count = 0
                        
                        // Sample nearby pixels for local baseline
                        for dy in -2...2 {
                            for dx in -2...2 {
                                let sampleX = pixelX + dx
                                let sampleY = pixelY + dy
                                if sampleX >= 0 && sampleX < width && sampleY >= 0 && sampleY < height {
                                    let sampleIndex = (sampleY * width + sampleX) * 4
                                    if sampleIndex + 2 < pixelData.count {
                                        localR += Int(pixelData[sampleIndex])
                                        localG += Int(pixelData[sampleIndex + 1])
                                        localB += Int(pixelData[sampleIndex + 2])
                                        count += 1
                                    }
                                }
                            }
                        }
                        
                        var hasModification = false
                        
                        if count > 0 {
                            // Look for variations that match overlay encoding
                            // Overlay uses: base+delta for 1-bits, base+0 for 0-bits
                            let rValue = Int(r)
                            let gValue = Int(g)
                            let bValue = Int(b)
                            
                            // Check if pixel values match overlay pattern
                            let isHighPattern = (
                                abs(rValue - WatermarkConstants.RGB_HIGH) <= WatermarkConstants.DETECTION_TOLERANCE &&
                                abs(gValue - WatermarkConstants.RGB_HIGH) <= WatermarkConstants.DETECTION_TOLERANCE &&
                                abs(bValue - WatermarkConstants.RGB_HIGH) <= WatermarkConstants.DETECTION_TOLERANCE
                            )
                            
                            let isLowPattern = (
                                abs(rValue - WatermarkConstants.RGB_LOW) <= WatermarkConstants.DETECTION_TOLERANCE &&
                                abs(gValue - WatermarkConstants.RGB_LOW) <= WatermarkConstants.DETECTION_TOLERANCE &&
                                abs(bValue - WatermarkConstants.RGB_LOW) <= WatermarkConstants.DETECTION_TOLERANCE
                            )
                            
                            if isHighPattern {
                                extractedBits.append(1)
                                hasModification = true
                            } else if isLowPattern {
                                extractedBits.append(0)
                                hasModification = true
                            } else {
                                // No clear pattern detected - might be background
                                extractedBits.append(0)
                            }
                        } else {
                            extractedBits.append(0)
                        }
                        
                        // Track confidence based on how many pixels show expected patterns
                        if hasModification {
                            confidence += 1
                        }
                        sampleCount += 1
                    }
                }
            }
        }
        
        if sampleCount > 0 {
            confidence /= Double(sampleCount)
            
            // Try to decode the extracted pattern
            if let decoded = decodeOverlayPattern(extractedBits) {
                return (decoded, confidence)
            }
        }
        
        return nil
    }
    
    private static func decodeOverlayPattern(_ bits: [UInt8]) -> String? {
        guard bits.count >= 16 else { return nil }
        
        // Extract length from first 16 bits (matching overlay encoding)
        var length: UInt16 = 0
        for i in 0..<16 {
            length |= UInt16(bits[i]) << i
        }
        
        guard length > 0 && length <= 8000 else { 
            // Try interpreting the pattern directly without length prefix
            return decodeOverlayPatternDirect(bits)
        }
        
        // Extract data bits
        var dataBits: [UInt8] = []
        for i in 16..<min(16 + Int(length), bits.count) {
            dataBits.append(bits[i])
        }
        
        // Convert bits to bytes with error correction
        let bytes = stride(from: 0, to: dataBits.count, by: 8).compactMap { startIndex -> UInt8? in
            guard startIndex + 7 < dataBits.count else { return nil }
            
            var byte: UInt8 = 0
            for i in 0..<8 {
                byte |= dataBits[startIndex + i] << i
            }
            return byte
        }
        
        if let decoded = String(data: Data(bytes), encoding: .utf8) {
            // Remove error correction (every character repeated 3 times)
            return removeSimpleErrorCorrection(decoded)
        }
        
        return nil
    }
    
    private static func decodeOverlayPatternDirect(_ bits: [UInt8]) -> String? {
        // Try to decode actual embedded patterns from bits
        
        // Convert bits to bytes and attempt to decode as UTF-8
        guard bits.count >= 8 else { return nil }
        
        var bytes: [UInt8] = []
        for i in stride(from: 0, to: bits.count - 7, by: 8) {
            var byte: UInt8 = 0
            for j in 0..<8 {
                if i + j < bits.count && bits[i + j] == 1 {
                    byte |= (1 << j)
                }
            }
            bytes.append(byte)
            
            // Stop if we have enough for a reasonable watermark
            if bytes.count > 200 { break }
        }
        
        // Try to decode as UTF-8 string
        if let string = String(bytes: bytes, encoding: .utf8) {
            // Only return if it looks like a watermark (contains colons and reasonable length)
            if string.contains(":") && string.count > 10 && string.count < 200 {
                return string
            }
        }
        
        return nil
    }
    
    private static func removeSimpleErrorCorrection(_ input: String) -> String {
        guard input.count % 3 == 0 else { return input }
        
        var result = ""
        for i in stride(from: 0, to: input.count, by: 3) {
            let startIndex = input.index(input.startIndex, offsetBy: i)
            let endIndex = input.index(startIndex, offsetBy: 3)
            let triplet = String(input[startIndex..<endIndex])
            
            // Use majority voting
            let chars = Array(triplet)
            if chars.count >= 3 {
                if chars[0] == chars[1] || chars[0] == chars[2] {
                    result.append(chars[0])
                } else {
                    result.append(chars[1])
                }
            }
        }
        
        return result
    }
    
    // MARK: - Spread Spectrum Watermarking
    
    private static func embedSpreadSpectrum(_ image: CGImage, watermark: String) -> CGImage? {
        guard let pixelData = extractPixelData(from: image) else { return nil }
        
        let width = image.width
        let height = image.height
        var modifiedData = pixelData
        
        // Generate pseudo-random sequence from watermark
        let sequence = generatePseudoRandomSequence(from: watermark, length: width * height)
        let watermarkBits = Data(watermark.utf8).flatMap { byte in
            (0..<8).map { (byte >> $0) & 1 }
        }
        
        var bitIndex = 0
        
        for i in 0..<(width * height) {
            if bitIndex >= watermarkBits.count { break }
            
            let pixelIndex = i * 4
            if pixelIndex + 2 < modifiedData.count {
                let bit = watermarkBits[bitIndex]
                let pseudoRandom = sequence[i]
                
                // Modulate with pseudo-random sequence
                let strength: Float = 3.0
                let modulation = pseudoRandom * (bit == 1 ? strength : -strength)
                
                // Apply to green channel (least perceptible)
                let original = Float(modifiedData[pixelIndex + 1])
                let modified = original + modulation
                modifiedData[pixelIndex + 1] = UInt8(max(0, min(255, modified)))
                
                bitIndex = (bitIndex + 1) % watermarkBits.count
            }
        }
        
        return createImage(from: modifiedData, width: width, height: height)
    }
    
    private static func extractSpreadSpectrum(from image: CGImage) -> String? {
        guard let pixelData = extractPixelData(from: image) else { return nil }
        
        let width = image.width
        let height = image.height
        
        // Try different watermark lengths
        for testLength in [10, 20, 50, 100] {
            let testWatermark = String(repeating: "a", count: testLength)
            let sequence = generatePseudoRandomSequence(from: testWatermark, length: width * height)
            
            var correlation: Float = 0
            var count = 0
            
            for i in 0..<min(sequence.count, width * height) {
                let pixelIndex = i * 4 + 1 // Green channel
                if pixelIndex < pixelData.count {
                    let pixelValue = Float(pixelData[pixelIndex]) - 128 // Center around 0
                    correlation += pixelValue * sequence[i]
                    count += 1
                }
            }
            
            if count > 0 {
                correlation /= Float(count)
                
                // If correlation is above threshold, try to extract
                if abs(correlation) > 5.0 {
                    return extractWatermarkWithSequence(from: pixelData, width: width, height: height, sequence: sequence)
                }
            }
        }
        
        return nil
    }
    
    private static func generatePseudoRandomSequence(from seed: String, length: Int) -> [Float] {
        var rng = UInt32(truncatingIfNeeded: abs(seed.hash))
        var sequence: [Float] = []
        
        for _ in 0..<length {
            rng = rng &* 1103515245 &+ 12345
            let normalized = Float(rng % 1000) / 500.0 - 1.0 // Range [-1, 1]
            sequence.append(normalized)
        }
        
        return sequence
    }
    
    private static func extractWatermarkWithSequence(from pixelData: [UInt8], width: Int, height: Int, sequence: [Float]) -> String? {
        var extractedBits: [UInt8] = []
        
        for i in 0..<min(sequence.count, width * height) {
            let pixelIndex = i * 4 + 1 // Green channel
            if pixelIndex < pixelData.count {
                let pixelValue = Float(pixelData[pixelIndex]) - 128
                let correlation = pixelValue * sequence[i]
                extractedBits.append(correlation > 0 ? 1 : 0)
            }
        }
        
        return reconstructStringFromBits(extractedBits)
    }
    
    // MARK: - DCT Watermarking
    
    private static func embedDCTWatermark(_ image: CGImage, watermark: String) -> CGImage? {
        guard let pixelData = extractFloatPixelData(from: image) else { return nil }
        
        let width = image.width
        let height = image.height
        let blockSize = 8
        
        var modifiedData = pixelData
        let watermarkData = Data(watermark.utf8)
        let watermarkBits = watermarkData.flatMap { byte in
            (0..<8).map { (byte >> $0) & 1 }
        }
        
        var bitIndex = 0
        
        // Process image in 8x8 blocks
        for blockY in stride(from: 0, to: height - blockSize, by: blockSize) {
            for blockX in stride(from: 0, to: width - blockSize, by: blockSize) {
                if bitIndex >= watermarkBits.count { break }
                
                embedInDCTBlock(&modifiedData, width: width, height: height,
                              blockX: blockX, blockY: blockY, blockSize: blockSize,
                              bit: watermarkBits[bitIndex])
                
                bitIndex = (bitIndex + 1) % watermarkBits.count
            }
        }
        
        return createImageFromFloatData(modifiedData, width: width, height: height)
    }
    
    private static func extractDCTWatermark(from image: CGImage) -> String? {
        guard let pixelData = extractFloatPixelData(from: image) else { return nil }
        
        let width = image.width
        let height = image.height
        let blockSize = 8
        
        var extractedBits: [UInt8] = []
        
        // Extract from 8x8 blocks
        for blockY in stride(from: 0, to: height - blockSize, by: blockSize) {
            for blockX in stride(from: 0, to: width - blockSize, by: blockSize) {
                let bit = extractFromDCTBlock(pixelData, width: width, height: height,
                                            blockX: blockX, blockY: blockY, blockSize: blockSize)
                extractedBits.append(bit)
            }
        }
        
        // Try to reconstruct watermark from bits
        return reconstructStringFromBits(extractedBits)
    }
    
    private static func embedInDCTBlock(_ data: inout [Float], width: Int, height: Int,
                                      blockX: Int, blockY: Int, blockSize: Int, bit: UInt8) {
        // Extract 8x8 luminance block
        var block = [Float](repeating: 0, count: blockSize * blockSize)
        
        for y in 0..<blockSize {
            for x in 0..<blockSize {
                let pixelIndex = ((blockY + y) * width + (blockX + x)) * 4
                if pixelIndex + 2 < data.count {
                    // Convert RGB to luminance
                    let r = data[pixelIndex]
                    let g = data[pixelIndex + 1]
                    let b = data[pixelIndex + 2]
                    block[y * blockSize + x] = 0.299 * r + 0.587 * g + 0.114 * b
                }
            }
        }
        
        // Apply DCT (simplified 2D DCT)
        var dctBlock = applyDCT(block, size: blockSize)
        
        // Embed bit in mid-frequency coefficient (position 3,2)
        let coefIndex = 3 * blockSize + 2
        if coefIndex < dctBlock.count {
            let strength: Float = 10.0
            if bit == 1 {
                dctBlock[coefIndex] += strength
            } else {
                dctBlock[coefIndex] -= strength
            }
        }
        
        // Apply inverse DCT
        let reconstructedBlock = applyInverseDCT(dctBlock, size: blockSize)
        
        // Put luminance changes back into RGB
        for y in 0..<blockSize {
            for x in 0..<blockSize {
                let pixelIndex = ((blockY + y) * width + (blockX + x)) * 4
                if pixelIndex + 2 < data.count {
                    let originalLum = 0.299 * data[pixelIndex] + 0.587 * data[pixelIndex + 1] + 0.114 * data[pixelIndex + 2]
                    let newLum = reconstructedBlock[y * blockSize + x]
                    let lumDiff = newLum - originalLum
                    
                    // Apply luminance change to RGB channels
                    data[pixelIndex] += lumDiff * 0.299
                    data[pixelIndex + 1] += lumDiff * 0.587
                    data[pixelIndex + 2] += lumDiff * 0.114
                    
                    // Clamp values
                    data[pixelIndex] = max(0, min(255, data[pixelIndex]))
                    data[pixelIndex + 1] = max(0, min(255, data[pixelIndex + 1]))
                    data[pixelIndex + 2] = max(0, min(255, data[pixelIndex + 2]))
                }
            }
        }
    }
    
    private static func extractFromDCTBlock(_ data: [Float], width: Int, height: Int,
                                          blockX: Int, blockY: Int, blockSize: Int) -> UInt8 {
        // Extract 8x8 luminance block
        var block = [Float](repeating: 0, count: blockSize * blockSize)
        
        for y in 0..<blockSize {
            for x in 0..<blockSize {
                let pixelIndex = ((blockY + y) * width + (blockX + x)) * 4
                if pixelIndex + 2 < data.count {
                    let r = data[pixelIndex]
                    let g = data[pixelIndex + 1]
                    let b = data[pixelIndex + 2]
                    block[y * blockSize + x] = 0.299 * r + 0.587 * g + 0.114 * b
                }
            }
        }
        
        // Apply DCT
        let dctBlock = applyDCT(block, size: blockSize)
        
        // Extract bit from mid-frequency coefficient
        let coefIndex = 3 * blockSize + 2
        if coefIndex < dctBlock.count {
            return dctBlock[coefIndex] > 0 ? 1 : 0
        }
        
        return 0
    }
    
    // MARK: - Redundant Embedding
    
    private static func embedRedundantWatermark(_ image: CGImage, watermark: String) -> CGImage? {
        guard let pixelData = extractPixelData(from: image) else { return nil }
        
        let width = image.width
        let height = image.height
        var modifiedData = pixelData
        
        // Add error correction
        let errorCorrectedData = addSimpleErrorCorrection(watermark)
        let watermarkBits = Data(errorCorrectedData.utf8).flatMap { byte in
            (0..<8).map { (byte >> $0) & 1 }
        }
        
        // Embed in multiple regions
        let regions = [
            (x: width / 4, y: height / 4, w: width / 4, h: height / 4),      // Top-left
            (x: 3 * width / 4, y: height / 4, w: width / 4, h: height / 4),  // Top-right
            (x: width / 4, y: 3 * height / 4, w: width / 4, h: height / 4),  // Bottom-left
            (x: 3 * width / 4, y: 3 * height / 4, w: width / 4, h: height / 4) // Bottom-right
        ]
        
        for region in regions {
            embedInRegion(&modifiedData, width: width, region: region, bits: watermarkBits)
        }
        
        return createImage(from: modifiedData, width: width, height: height)
    }
    
    private static func extractRedundantWatermark(from image: CGImage) -> String? {
        guard let pixelData = extractPixelData(from: image) else { return nil }
        
        let width = image.width
        let height = image.height
        
        let regions = [
            (x: width / 4, y: height / 4, w: width / 4, h: height / 4),
            (x: 3 * width / 4, y: height / 4, w: width / 4, h: height / 4),
            (x: width / 4, y: 3 * height / 4, w: width / 4, h: height / 4),
            (x: 3 * width / 4, y: 3 * height / 4, w: width / 4, h: height / 4)
        ]
        
        // Extract from each region and vote
        var allExtracted: [[UInt8]] = []
        
        for region in regions {
            let extracted = extractFromRegion(pixelData, width: width, region: region)
            if !extracted.isEmpty {
                allExtracted.append(extracted)
            }
        }
        
        guard !allExtracted.isEmpty else { return nil }
        
        // Use majority voting to reconstruct bits
        let maxLength = allExtracted.map { $0.count }.max() ?? 0
        var votedBits: [UInt8] = []
        
        for i in 0..<maxLength {
            var votes = [UInt8: Int]()
            for extracted in allExtracted {
                if i < extracted.count {
                    votes[extracted[i], default: 0] += 1
                }
            }
            if let mostVoted = votes.max(by: { $0.value < $1.value }) {
                votedBits.append(mostVoted.key)
            }
        }
        
        let reconstructed = reconstructStringFromBits(votedBits)
        return removeSimpleErrorCorrection(reconstructed)
    }
    
    // MARK: - Micro QR Pattern
    
    private static func embedMicroQRPattern(_ image: CGImage, watermark: String) -> CGImage? {
        guard let pixelData = extractPixelData(from: image) else { return nil }
        
        let width = image.width
        let height = image.height
        var modifiedData = pixelData
        
        // Create a simple 2D barcode-like pattern
        let pattern = generateMicroPattern(from: watermark)
        let patternSize = 32
        
        // Embed pattern in corner (very subtle)
        let startX = width - patternSize - 10
        let startY = 10
        
        for y in 0..<patternSize {
            for x in 0..<patternSize {
                let pixelIndex = ((startY + y) * width + (startX + x)) * 4
                if pixelIndex + 3 < modifiedData.count {
                    let patternValue = pattern[y * patternSize + x]
                    let modification: UInt8 = patternValue == 1 ? 2 : 0
                    
                    // Very subtle modification to RGB
                    modifiedData[pixelIndex] = (modifiedData[pixelIndex] & 0xFC) | (modification & 0x03)
                    modifiedData[pixelIndex + 1] = (modifiedData[pixelIndex + 1] & 0xFC) | (modification & 0x03)
                    modifiedData[pixelIndex + 2] = (modifiedData[pixelIndex + 2] & 0xFC) | (modification & 0x03)
                }
            }
        }
        
        return createImage(from: modifiedData, width: width, height: height)
    }
    
    private static func extractMicroQRPattern(from image: CGImage) -> String? {
        guard let pixelData = extractPixelData(from: image) else { 
            print("DEBUG: Failed to extract pixel data")
            return nil 
        }
        
        let width = image.width
        let _ = image.height
        let patternSize = 32
        
        let startX = width - patternSize - 10
        let startY = 10
        
        print("DEBUG: Extracting micro QR from position (\(startX), \(startY))")
        
        var extractedPattern: [UInt8] = []
        
        for y in 0..<patternSize {
            for x in 0..<patternSize {
                let pixelIndex = ((startY + y) * width + (startX + x)) * 4
                if pixelIndex + 2 < pixelData.count {
                    let r = pixelData[pixelIndex] & 0x03
                    let g = pixelData[pixelIndex + 1] & 0x03
                    let b = pixelData[pixelIndex + 2] & 0x03
                    
                    let avgModification = (Int(r) + Int(g) + Int(b)) / 3
                    extractedPattern.append(avgModification > 1 ? 1 : 0)
                } else {
                    print("DEBUG: Pixel index out of bounds: \(pixelIndex)")
                    return nil
                }
            }
        }
        
        print("DEBUG: Extracted pattern length: \(extractedPattern.count)")
        print("DEBUG: First 32 bits: \(Array(extractedPattern.prefix(32)))")
        
        let result = decodeMicroPattern(extractedPattern)
        print("DEBUG: Decoded result: \(result ?? "nil")")
        return result
    }
    
    // MARK: - Helper Functions
    
    private static func extractPixelData(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow
        
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        guard let ctx = context else { return nil }
        
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return pixelData
    }
    
    private static func extractFloatPixelData(from image: CGImage) -> [Float]? {
        guard let pixelData = extractPixelData(from: image) else { return nil }
        return pixelData.map { Float($0) }
    }
    
    private static func createImage(from pixelData: [UInt8], width: Int, height: Int) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var mutablePixelData = pixelData
        let context = mutablePixelData.withUnsafeMutableBytes { bytes in
            CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        }
        
        return context?.makeImage()
    }
    
    private static func createImageFromFloatData(_ floatData: [Float], width: Int, height: Int) -> CGImage? {
        let pixelData = floatData.map { UInt8(max(0, min(255, $0))) }
        return createImage(from: pixelData, width: width, height: height)
    }
    
    private static func applyDCT(_ block: [Float], size: Int) -> [Float] {
        // Simplified 2D DCT implementation
        var result = [Float](repeating: 0, count: size * size)
        
        for u in 0..<size {
            for v in 0..<size {
                var sum: Float = 0
                for x in 0..<size {
                    for y in 0..<size {
                        sum += block[y * size + x] * 
                               cos(Float.pi * Float(u) * (Float(x) + 0.5) / Float(size)) *
                               cos(Float.pi * Float(v) * (Float(y) + 0.5) / Float(size))
                    }
                }
                let cu: Float = u == 0 ? 1.0 / sqrt(2.0) : 1.0
                let cv: Float = v == 0 ? 1.0 / sqrt(2.0) : 1.0
                result[v * size + u] = 0.25 * cu * cv * sum
            }
        }
        
        return result
    }
    
    private static func applyInverseDCT(_ dctBlock: [Float], size: Int) -> [Float] {
        // Simplified 2D inverse DCT implementation
        var result = [Float](repeating: 0, count: size * size)
        
        for x in 0..<size {
            for y in 0..<size {
                var sum: Float = 0
                for u in 0..<size {
                    for v in 0..<size {
                        let cu: Float = u == 0 ? 1.0 / sqrt(2.0) : 1.0
                        let cv: Float = v == 0 ? 1.0 / sqrt(2.0) : 1.0
                        let cosU = cos(Float.pi * Float(u) * (Float(x) + 0.5) / Float(size))
                        let cosV = cos(Float.pi * Float(v) * (Float(y) + 0.5) / Float(size))
                        sum += cu * cv * dctBlock[v * size + u] * cosU * cosV
                    }
                }
                result[y * size + x] = 0.25 * sum
            }
        }
        
        return result
    }
    
    private static func addSimpleErrorCorrection(_ input: String) -> String {
        // Simple repetition code - repeat each character 3 times
        return input.map { String(repeating: String($0), count: 3) }.joined()
    }
    
    private static func removeSimpleErrorCorrection(_ input: String?) -> String? {
        guard let input = input, input.count % 3 == 0 else { return input }
        
        var result = ""
        for i in stride(from: 0, to: input.count, by: 3) {
            let startIndex = input.index(input.startIndex, offsetBy: i)
            let endIndex = input.index(startIndex, offsetBy: 3)
            let triplet = String(input[startIndex..<endIndex])
            
            // Use majority voting
            let chars = Array(triplet)
            if chars[0] == chars[1] || chars[0] == chars[2] {
                result.append(chars[0])
            } else {
                result.append(chars[1])
            }
        }
        
        return result
    }
    
    private static func embedInRegion(_ data: inout [UInt8], width: Int, 
                                    region: (x: Int, y: Int, w: Int, h: Int), bits: [UInt8]) {
        var bitIndex = 0
        
        for y in region.y..<min(region.y + region.h, data.count / (width * 4)) {
            for x in region.x..<min(region.x + region.w, width) {
                if bitIndex >= bits.count { break }
                
                let pixelIndex = (y * width + x) * 4
                if pixelIndex + 2 < data.count {
                    let bit = bits[bitIndex]
                    
                    // Embed in blue channel LSB
                    data[pixelIndex + 2] = (data[pixelIndex + 2] & 0xFE) | bit
                    
                    bitIndex += 1
                }
            }
            if bitIndex >= bits.count { break }
        }
    }
    
    private static func extractFromRegion(_ data: [UInt8], width: Int, 
                                        region: (x: Int, y: Int, w: Int, h: Int)) -> [UInt8] {
        var extractedBits: [UInt8] = []
        
        for y in region.y..<min(region.y + region.h, data.count / (width * 4)) {
            for x in region.x..<min(region.x + region.w, width) {
                let pixelIndex = (y * width + x) * 4
                if pixelIndex + 2 < data.count {
                    extractedBits.append(data[pixelIndex + 2] & 1)
                }
            }
        }
        
        return extractedBits
    }
    
    private static func reconstructStringFromBits(_ bits: [UInt8]) -> String? {
        guard bits.count >= 8 else { return nil }
        
        let bytes = stride(from: 0, to: bits.count, by: 8).compactMap { startIndex -> UInt8? in
            guard startIndex + 7 < bits.count else { return nil }
            
            var byte: UInt8 = 0
            for i in 0..<8 {
                byte |= bits[startIndex + i] << i
            }
            return byte
        }
        
        return String(data: Data(bytes), encoding: .utf8)
    }
    
    private static func generateMicroPattern(from string: String) -> [UInt8] {
        // Create a simple 2D barcode from the string
        let data = Data(string.utf8)
        let bits = data.flatMap { byte in
            (0..<8).map { (byte >> $0) & 1 }
        }
        
        var pattern = [UInt8](repeating: 0, count: 32 * 32)
        
        // Embed length in first 16 bits
        let length = UInt16(bits.count)
        for i in 0..<16 {
            pattern[i] = UInt8((length >> i) & 1)
        }
        
        // Embed data bits
        for (index, bit) in bits.enumerated() {
            if index + 16 < pattern.count {
                pattern[index + 16] = UInt8(bit)
            }
        }
        
        return pattern
    }
    
    private static func decodeMicroPattern(_ pattern: [UInt8]) -> String? {
        guard pattern.count >= 16 else { return nil }
        
        // Extract length
        var length: UInt16 = 0
        for i in 0..<16 {
            length |= UInt16(pattern[i]) << i
        }
        
        guard length > 0 && length <= 1000 else { return nil }
        
        // Extract data bits
        var bits: [UInt8] = []
        for i in 16..<min(16 + Int(length), pattern.count) {
            bits.append(pattern[i])
        }
        
        // Convert bits to bytes
        let bytes = stride(from: 0, to: bits.count, by: 8).compactMap { startIndex -> UInt8? in
            guard startIndex + 7 < bits.count else { return nil }
            
            var byte: UInt8 = 0
            for i in 0..<8 {
                byte |= bits[startIndex + i] << i
            }
            return byte
        }
        
        return String(data: Data(bytes), encoding: .utf8)
    }
}