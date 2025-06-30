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
    
    static func extractPhotoResistantWatermark(from image: CGImage, threshold: Double = WatermarkConstants.PHOTO_CONFIDENCE_THRESHOLD, verbose: Bool = false, debug: Bool = false) -> String? {
        // Try overlay-specific extraction first (for camera photos of screens)
        if let overlayResult = extractOverlayWatermark(from: image, threshold: threshold, verbose: verbose, debug: debug) {
            return overlayResult
        }
        
        if debug { print("Debug: Overlay extraction failed, trying redundant...") }
        
        // Try multiple extraction methods in order of robustness
        if let redundantResult = extractRedundantWatermark(from: image) { 
            if debug { print("Debug: Redundant extraction succeeded") }
            return redundantResult 
        }
        
        if debug { print("Debug: Redundant extraction failed, trying micro QR...") }
        
        if let qrResult = extractMicroQRPattern(from: image) { 
            if debug { print("Debug: Micro QR extraction succeeded") }
            return qrResult 
        }
        
        if debug { print("Debug: Micro QR extraction failed, trying spread spectrum...") }
        
        if let spreadResult = extractSpreadSpectrum(from: image) { 
            if debug { print("Debug: Spread spectrum extraction succeeded") }
            return spreadResult 
        }
        
        if debug { print("Debug: All WatermarkEngine methods failed") }
        
        return nil
    }
    
    // MARK: - Overlay Watermark Extraction (for camera photos of screens)
    
    private static func calculateAdaptiveThreshold(_ pixelData: [UInt8], width: Int, height: Int, baseThreshold: Double, verbose: Bool = false) -> Double {
        if verbose { print(".  Calculating adaptive threshold...") }
        // Calculate image variance to determine if we should be more/less aggressive
        var totalVariance: Double = 0
        var sampleCount = 0
        let sampleStep = max(1, (width * height) / 1000) // Sample ~1000 pixels
        if verbose { print(".    Sampling every \(sampleStep) pixels for variance calculation") }
        
        for i in stride(from: 0, to: pixelData.count - 4, by: sampleStep * 4) {
            let _ = Double(pixelData[i])
            let _ = Double(pixelData[i + 1])  
            let _ = Double(pixelData[i + 2])
            
            // Calculate local variance in a 3x3 window
            var localPixels: [Double] = []
            let pixelIndex = i / 4
            let x = pixelIndex % width
            let y = pixelIndex / width
            
            for dy in -1...1 {
                for dx in -1...1 {
                    let nx = x + dx
                    let ny = y + dy
                    if nx >= 0 && nx < width && ny >= 0 && ny < height {
                        let nIndex = (ny * width + nx) * 4
                        if nIndex + 2 < pixelData.count {
                            let nr = Double(pixelData[nIndex])
                            let ng = Double(pixelData[nIndex + 1])
                            let nb = Double(pixelData[nIndex + 2])
                            let brightness = (nr + ng + nb) / 3.0
                            localPixels.append(brightness)
                        }
                    }
                }
            }
            
            if localPixels.count > 1 {
                let mean = localPixels.reduce(0, +) / Double(localPixels.count)
                let variance = localPixels.map { pow($0 - mean, 2) }.reduce(0, +) / Double(localPixels.count)
                totalVariance += variance
                sampleCount += 1
            }
        }
        
        let avgVariance = sampleCount > 0 ? totalVariance / Double(sampleCount) : 0
        
        if verbose { print(".    Average image variance: \(String(format: "%.2f")) (from \(sampleCount) samples)") }
        
        // Lower threshold for low-variance (smooth) images, higher for high-variance (noisy) images
        // More aggressive thresholds for better camera photo detection
        let varianceThreshold = WatermarkConstants.VARIANCE_THRESHOLD
        let thresholdMultiplier = avgVariance < varianceThreshold ? WatermarkConstants.SMOOTH_IMAGE_MULTIPLIER : WatermarkConstants.NOISY_IMAGE_MULTIPLIER
        let adaptiveThreshold = baseThreshold * thresholdMultiplier
        
        if verbose { print(".    Image type: \(avgVariance < varianceThreshold ? "smooth" : "noisy")") }
        if verbose { print(".    Threshold multiplier: \(String(format: "%.1f", thresholdMultiplier))") }
        if verbose { print(".    Base threshold: \(String(format: "%.3f")) -> Adaptive threshold: \(String(format: "%.3f", adaptiveThreshold))") }
        
        return adaptiveThreshold
    }
    
    private static func extractOverlayWatermark(from image: CGImage, threshold: Double = WatermarkConstants.PHOTO_CONFIDENCE_THRESHOLD, verbose: Bool = false, debug: Bool = false) -> String? {
        guard let pixelData = extractPixelData(from: image) else { return nil }
        
        let width = image.width
        let height = image.height
        
        if verbose { print(".  Trying overlay watermark extraction...") }
        // Try more aggressive tile sizes (camera might scale the overlay differently)
        // Center around PATTERN_SIZE (64) with variations for camera scaling
        let patternSize = WatermarkConstants.PATTERN_SIZE
        let tileSizes = [8, 12, 16, 24, 32, 40, 48, 56, patternSize, 80, 96, patternSize * 2]
        
        // Sample multiple regions to find the strongest pattern - more comprehensive grid
        var bestResult: String?
        var bestScore = 0.0
        
        if verbose { 
            print("watermark overlay detection starting") 
            print(".  Image size: \(width)x\(height)") 
            print(".  Testing \(tileSizes.count) different tile sizes: \(tileSizes)")
        } else {
            print("Analyzing image...", terminator: "")
        }

        for (index, tileSize) in tileSizes.enumerated() {
            if verbose { 
                print(".  Trying tile size: \(tileSize)x\(tileSize)") 
            } else if index % 3 == 0 {
                print(".", terminator: "")
                fflush(stdout)
            }
            // More aggressive position sampling - 5x5 grid plus corners and edges
            var samplePositions: [(x: Int, y: Int)] = []
            
            // Grid sampling (5x5)
            for gridY in 0..<5 {
                for gridX in 0..<5 {
                    let x = (width * gridX) / 4
                    let y = (height * gridY) / 4
                    samplePositions.append((x: x, y: y))
                }
            }
            
            // Edge sampling
            let edgeStep = min(width, height) / 10
            for i in stride(from: 0, to: width - tileSize, by: edgeStep) {
                samplePositions.append((x: i, y: 0))  // Top edge
                samplePositions.append((x: i, y: height - tileSize))  // Bottom edge
            }
            for i in stride(from: 0, to: height - tileSize, by: edgeStep) {
                samplePositions.append((x: 0, y: i))  // Left edge  
                samplePositions.append((x: width - tileSize, y: i))  // Right edge
            }
            
            if verbose { print(".    Generated \(samplePositions.count) sample positions") }
            var positionCount = 0
            
            for position in samplePositions {
                positionCount += 1
                if let (result, score) = extractOverlayPatternAt(pixelData, width: width, height: height, 
                                                               startX: position.x, startY: position.y, tileSize: tileSize,
                                                               scaleFactor: Double(tileSize) / 32.0, verbose: verbose) {
                    if verbose { print(".      Position \(positionCount)/\(samplePositions.count) (\(position.x),\(position.y)): found pattern '\(result)' with score \(String(format: "%.3f", score))") }
                    if score > bestScore {
                        if verbose { print(".      *** New best score! Previous: \(String(format: "%.3f", bestScore))") }
                        bestScore = score
                        bestResult = result
                    }
                } else if verbose && positionCount % 10 == 0 {
                    print(".      Position \(positionCount)/\(samplePositions.count): no pattern found")
                }
            }
        }
        if verbose { print(".  bestResult detected: \(bestResult ?? "nil")") }

        // Adaptive threshold based on image characteristics
        let adaptiveThreshold = calculateAdaptiveThreshold(pixelData, width: width, height: height, baseThreshold: threshold, verbose: verbose)
        
        if verbose { 
            print(".  Final score: \(String(format: "%.3f", bestScore)), adaptive threshold: \(String(format: "%.3f", adaptiveThreshold))") 
        } else {
            print(" done")
        }
        let passed = bestScore > adaptiveThreshold && bestResult != nil && !bestResult!.isEmpty
        if verbose { print(".  Threshold check: \(passed ? "PASSED" : "FAILED") - \(passed ? "watermark detected" : "no watermark found")") }
        
        if debug && !passed {
            print("Debug: Overlay extraction failed:")
            print("  - Best score: \(String(format: "%.3f", bestScore))")
            print("  - Adaptive threshold: \(String(format: "%.3f", adaptiveThreshold))")
            print("  - Score above threshold: \(bestScore > adaptiveThreshold)")
            print("  - Best result found: \(bestResult != nil)")
            if let result = bestResult {
                print("  - Result not empty: \(!result.isEmpty)")
                print("  - Result content: '\(result)'")
            }
        }
        
        return passed ? bestResult : nil  
    }
    
    private static func extractOverlayPatternAt(_ pixelData: [UInt8], width: Int, height: Int, 
                                              startX: Int, startY: Int, tileSize: Int, scaleFactor: Double = 1.0, verbose: Bool = false) -> (String, Double)? {
        var extractedBits: [UInt8] = []
        var confidence: Double = 0
        var sampleCount = 0
        var patternMatches = 0
        
        // More generous tolerance for camera photos with compression artifacts
        let scaledTolerance = Int(Double(WatermarkConstants.DETECTION_TOLERANCE) * max(1.0, scaleFactor * 1.5))
        
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
                        
                        // Convert to different color spaces for better detection
                        let (_, _, _) = rgbToHsv(r: Int(r), g: Int(g), b: Int(b))
                        let (y, _, _) = rgbToYuv(r: Int(r), g: Int(g), b: Int(b))
                        
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
                            
                            // Use pre-calculated scaled tolerance
                            
                            // Check if pixel values match overlay pattern in RGB space
                            let isHighPatternRGB = (
                                abs(rValue - WatermarkConstants.RGB_HIGH) <= scaledTolerance &&
                                abs(gValue - WatermarkConstants.RGB_HIGH) <= scaledTolerance &&
                                abs(bValue - WatermarkConstants.RGB_HIGH) <= scaledTolerance
                            )
                            
                            let isLowPatternRGB = (
                                abs(rValue - WatermarkConstants.RGB_LOW) <= scaledTolerance &&
                                abs(gValue - WatermarkConstants.RGB_LOW) <= scaledTolerance &&
                                abs(bValue - WatermarkConstants.RGB_LOW) <= scaledTolerance
                            )
                            
                            // Also check in luminance (Y) channel which is more robust to color shifts
                            let expectedHighY = rgbToYuv(r: WatermarkConstants.RGB_HIGH, g: WatermarkConstants.RGB_HIGH, b: WatermarkConstants.RGB_HIGH).0
                            let expectedLowY = rgbToYuv(r: WatermarkConstants.RGB_LOW, g: WatermarkConstants.RGB_LOW, b: WatermarkConstants.RGB_LOW).0
                            
                            let isHighPatternY = abs(y - expectedHighY) <= scaledTolerance * 2
                            let isLowPatternY = abs(y - expectedLowY) <= scaledTolerance * 2
                            
                            // Combine RGB and luminance detection
                            let isHighPattern = isHighPatternRGB || isHighPatternY
                            let isLowPattern = isLowPatternRGB || isLowPatternY
                            
                            if isHighPattern {
                                extractedBits.append(1)
                                hasModification = true
                                patternMatches += 1
                            } else if isLowPattern {
                                extractedBits.append(0)
                                hasModification = true
                                patternMatches += 1
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
            let patternMatchRate = Double(patternMatches) / Double(sampleCount)
            
            // Only proceed if we have a reasonable pattern match rate
            if patternMatchRate > 0.1 {
                // Apply noise filtering to extracted bits
                let filteredBits = applyNoiseFiltering(extractedBits, tileSize: tileSize, verbose: verbose)
                
                // Try to decode the filtered pattern
                if let decoded = decodeOverlayPattern(filteredBits, verbose: verbose) {
                    return (decoded, confidence)
                }
                
                // Fallback: try original pattern if filtering failed
                if let decoded = decodeOverlayPattern(extractedBits, verbose: verbose) {
                    return (decoded, confidence)
                }
            }
        }
        
        return nil
    }
    
    private static func decodeOverlayPattern(_ bits: [UInt8], verbose: Bool = false) -> String? {
        guard bits.count >= 16 else { 
            if verbose { print(".        Decode failed: insufficient bits (\(bits.count) < 16)") }
            return nil 
        }
        
        // Extract length from first 16 bits (matching overlay encoding)
        var length: UInt16 = 0
        for i in 0..<16 {
            length |= UInt16(bits[i]) << i
        }
        
        if verbose { print(".        Extracted length: \(length)") }
        
        guard length > 0 && length <= 8000 else { 
            if verbose { print(".        Invalid length, trying direct pattern decode...") }
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
            if verbose { print(".        Decoded raw string: '\(decoded)'") }
            // Remove error correction (every character repeated 3 times)
            let final = removeSimpleErrorCorrection(decoded)
            if verbose { print(".        After error correction: '\(final)'") }
            return final
        }
        
        if verbose { print(".        UTF-8 decode failed") }
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
                    let pixelValue = Float(pixelData[pixelIndex]) - Float(WatermarkConstants.RGB_BASE) // Center around 0
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
                let pixelValue = Float(pixelData[pixelIndex]) - Float(WatermarkConstants.RGB_BASE)
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
        let margin = 10
        let menuBarOffset = 40  // Move QR codes below menu bar area
        
        // Define all four corner positions
        let corners = [
            (x: width - patternSize - margin, y: menuBarOffset),                    // Top-right
            (x: margin, y: menuBarOffset),                                          // Top-left  
            (x: width - patternSize - margin, y: height - patternSize - margin),   // Bottom-right
            (x: margin, y: height - patternSize - margin)                          // Bottom-left
        ]
        
        // Embed pattern in all four corners
        for corner in corners {
            for y in 0..<patternSize {
                for x in 0..<patternSize {
                    let pixelIndex = ((corner.y + y) * width + (corner.x + x)) * 4
                    if pixelIndex + 3 < modifiedData.count {
                        let patternValue = pattern[y * patternSize + x]
                        
                        // Use same contrast as main watermark for better camera detection
                        if patternValue == 1 {
                            // Set to RGB_HIGH for 1-bits
                            modifiedData[pixelIndex] = UInt8(WatermarkConstants.RGB_HIGH)
                            modifiedData[pixelIndex + 1] = UInt8(WatermarkConstants.RGB_HIGH)
                            modifiedData[pixelIndex + 2] = UInt8(WatermarkConstants.RGB_HIGH)
                        } else {
                            // Set to RGB_LOW for 0-bits
                            modifiedData[pixelIndex] = UInt8(WatermarkConstants.RGB_LOW)
                            modifiedData[pixelIndex + 1] = UInt8(WatermarkConstants.RGB_LOW)
                            modifiedData[pixelIndex + 2] = UInt8(WatermarkConstants.RGB_LOW)
                        }
                    }
                }
            }
        }
        
        return createImage(from: modifiedData, width: width, height: height)
    }
    
    private static func extractMicroQRPattern(from image: CGImage) -> String? {
        guard let pixelData = extractPixelData(from: image) else { 
            print(".  Failed to extract pixel data")
            return nil 
        }
        
        let width = image.width
        let height = image.height
        let patternSize = 32
        let margin = 10
        let menuBarOffset = 40  // Same offset used in embedding
        
        // Define all four corner positions (same as embedding)
        let corners = [
            (x: width - patternSize - margin, y: menuBarOffset, name: "Top-right"),                    
            (x: margin, y: menuBarOffset, name: "Top-left"),                                          
            (x: width - patternSize - margin, y: height - patternSize - margin, name: "Bottom-right"),   
            (x: margin, y: height - patternSize - margin, name: "Bottom-left")                          
        ]
        
        print("Extracting micro QR from all four corners...")
        
        // Try extraction from each corner
        for corner in corners {
            print(".  Trying \(corner.name) corner at (\(corner.x), \(corner.y))")
            
            var extractedPattern: [UInt8] = []
            var validExtraction = true
            
            for y in 0..<patternSize {
                for x in 0..<patternSize {
                    let pixelIndex = ((corner.y + y) * width + (corner.x + x)) * 4
                    if pixelIndex + 2 < pixelData.count {
                        let r = Int(pixelData[pixelIndex])
                        let g = Int(pixelData[pixelIndex + 1])
                        let b = Int(pixelData[pixelIndex + 2])
                        
                        // Use same detection logic as main watermark
                        let avgRGB = (r + g + b) / 3
                        let tolerance = WatermarkConstants.DETECTION_TOLERANCE
                        
                        let isHigh = abs(avgRGB - WatermarkConstants.RGB_HIGH) <= tolerance
                        let isLow = abs(avgRGB - WatermarkConstants.RGB_LOW) <= tolerance
                        
                        if isHigh {
                            extractedPattern.append(1)
                        } else if isLow {
                            extractedPattern.append(0)
                        } else {
                            // Fallback: use threshold midpoint
                            let midpoint = (WatermarkConstants.RGB_HIGH + WatermarkConstants.RGB_LOW) / 2
                            extractedPattern.append(avgRGB > midpoint ? 1 : 0)
                        }
                    } else {
                        print(".    Pixel index out of bounds: \(pixelIndex)")
                        validExtraction = false
                        break
                    }
                }
                if !validExtraction { break }
            }
            
            if validExtraction {
                print(".    Extracted pattern length: \(extractedPattern.count)")
                print(".    First 32 bits: \(Array(extractedPattern.prefix(32)))")
                
                if let result = decodeMicroPattern(extractedPattern) {
                    print(".    Successfully decoded from \(corner.name) corner: \(result)")
                    return result
                } else {
                    print(".    Failed to decode from \(corner.name) corner")
                }
            }
        }
        
        print(".  No valid QR pattern found in any corner")
        return nil
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
    
    // MARK: - Color Space Conversions
    
    private static func rgbToHsv(r: Int, g: Int, b: Int) -> (h: Int, s: Int, v: Int) {
        let rf = Double(r) / 255.0
        let gf = Double(g) / 255.0
        let bf = Double(b) / 255.0
        
        let maxVal = max(rf, gf, bf)
        let minVal = min(rf, gf, bf)
        let diff = maxVal - minVal
        
        var h: Double = 0
        let s: Double = maxVal == 0 ? 0 : diff / maxVal
        let v: Double = maxVal
        
        if diff != 0 {
            if maxVal == rf {
                h = 60 * ((gf - bf) / diff)
            } else if maxVal == gf {
                h = 60 * (2 + (bf - rf) / diff)
            } else {
                h = 60 * (4 + (rf - gf) / diff)
            }
            if h < 0 { h += 360 }
        }
        
        return (h: Int(h), s: Int(s * 255), v: Int(v * 255))
    }
    
    private static func rgbToYuv(r: Int, g: Int, b: Int) -> (y: Int, u: Int, v: Int) {
        let rf = Double(r)
        let gf = Double(g)
        let bf = Double(b)
        
        let y = 0.299 * rf + 0.587 * gf + 0.114 * bf
        let u = -0.14713 * rf - 0.28886 * gf + 0.436 * bf + Double(WatermarkConstants.RGB_BASE)
        let v = 0.615 * rf - 0.51499 * gf - 0.10001 * bf + Double(WatermarkConstants.RGB_BASE)
        
        return (y: Int(y), u: Int(u), v: Int(v))
    }
    
    // MARK: - Noise Filtering and Signal Enhancement
    
    private static func applyNoiseFiltering(_ bits: [UInt8], tileSize: Int, verbose: Bool = false) -> [UInt8] {
        guard bits.count >= 9 else { 
            if verbose { print(".        Noise filtering skipped: too few bits (\(bits.count))") }
            return bits 
        }
        
        if verbose { print(".        Applying noise filtering to \(bits.count) bits...") }
        var filteredBits = bits
        let side = tileSize
        var medianFilterChanges = 0
        var majorityVoteChanges = 0
        
        // Apply median filter to reduce noise
        for y in 1..<(side - 1) {
            for x in 1..<(side - 1) {
                let index = y * side + x
                if index < bits.count {
                    var neighbors: [UInt8] = []
                    
                    // Collect 3x3 neighborhood
                    for dy in -1...1 {
                        for dx in -1...1 {
                            let neighborIndex = (y + dy) * side + (x + dx)
                            if neighborIndex >= 0 && neighborIndex < bits.count {
                                neighbors.append(bits[neighborIndex])
                            }
                        }
                    }
                    
                    // Apply median filter
                    neighbors.sort()
                    if neighbors.count >= 5 {
                        let medianValue = neighbors[neighbors.count / 2]
                        if filteredBits[index] != medianValue {
                            medianFilterChanges += 1
                        }
                        filteredBits[index] = medianValue
                    }
                }
            }
        }
        
        // Apply majority voting in 3x3 windows for error correction
        var correctedBits = filteredBits
        for y in 1..<(side - 1) {
            for x in 1..<(side - 1) {
                let index = y * side + x
                if index < filteredBits.count {
                    var ones = 0
                    var zeros = 0
                    
                    // Count 1s and 0s in 3x3 neighborhood
                    for dy in -1...1 {
                        for dx in -1...1 {
                            let neighborIndex = (y + dy) * side + (x + dx)
                            if neighborIndex >= 0 && neighborIndex < filteredBits.count {
                                if filteredBits[neighborIndex] == 1 {
                                    ones += 1
                                } else {
                                    zeros += 1
                                }
                            }
                        }
                    }
                    
                    // Apply majority voting
                    let newValue: UInt8 = ones > zeros ? 1 : 0
                    if correctedBits[index] != newValue {
                        majorityVoteChanges += 1
                    }
                    correctedBits[index] = newValue
                }
            }
        }
        
        if verbose { print(".        Median filter changed \(medianFilterChanges) bits") }
        if verbose { print(".        Majority vote changed \(majorityVoteChanges) bits") }
        
        return correctedBits
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