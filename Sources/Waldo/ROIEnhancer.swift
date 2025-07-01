import CoreGraphics
import Foundation
import Accelerate
import Vision

/// ROI (Region of Interest) enhancer for targeted watermark detection
/// Implements contrast enhancement, thresholding, and morphological operations
/// specifically for micro-QR and watermark patterns in known positions
class ROIEnhancer {
    
    // MARK: - ROI Configuration
    
    /// Known QR code positions based on embedding logic
    struct QRPosition {
        let x: Int
        let y: Int
        let width: Int
        let height: Int
        let name: String
        let type: QRType
    }
    
    enum QRType {
        case embedded    // 32x32 embedded QR codes
        case overlay     // 25x25 overlay QR codes (100x100 pixels total)
    }
    
    // MARK: - Public Interface
    
    static func enhanceROIsForWatermarkDetection(from image: CGImage, verbose: Bool = false) -> [(region: CGImage, position: QRPosition)] {
        return enhanceROIsForWatermarkDetection(from: image, optimizeForQR: true, verbose: verbose)
    }
    
    static func enhanceROIsForWatermarkDetection(from image: CGImage, optimizeForQR: Bool, verbose: Bool = false) -> [(region: CGImage, position: QRPosition)] {
        if verbose { print("Starting ROI enhancement for watermark detection...") }
        
        let imageWidth = image.width
        let imageHeight = image.height
        
        // Get all known QR positions
        let qrPositions = getKnownQRPositions(imageWidth: imageWidth, imageHeight: imageHeight)
        
        if verbose { print("Processing \(qrPositions.count) ROI positions...") }
        
        var enhancedROIs: [(region: CGImage, position: QRPosition)] = []
        
        for position in qrPositions {
            if verbose { print("Processing \(position.name) ROI at (\(position.x), \(position.y)) size \(position.width)x\(position.height)") }
            
            // Extract ROI from source image
            guard let roiImage = extractROI(from: image, position: position, verbose: verbose) else {
                if verbose { print("Failed to extract ROI for \(position.name)") }
                continue
            }
            
            // Apply enhancement pipeline
            guard let enhancedROI = enhanceROI(roiImage, position: position, optimizeForQR: optimizeForQR, verbose: verbose) else {
                if verbose { print("Failed to enhance ROI for \(position.name)") }
                continue
            }
            
            enhancedROIs.append((region: enhancedROI, position: position))
            
            if verbose { print("Successfully enhanced \(position.name) ROI") }
        }
        
        if verbose { print("ROI enhancement completed: \(enhancedROIs.count)/\(qrPositions.count) regions processed") }
        return enhancedROIs
    }
    
    // MARK: - ROI Position Calculation
    
    private static func getKnownQRPositions(imageWidth: Int, imageHeight: Int) -> [QRPosition] {
        var positions: [QRPosition] = []
        
        // Embedded QR positions (32x32 pixels)
        let embeddedSize = 32
        let embeddedMargin = 10
        let menuBarOffset = 50  // Increased offset for larger Version 2 QR codes
        
        let embeddedPositions = [
            (x: imageWidth - embeddedSize - embeddedMargin, y: menuBarOffset, name: "Embedded-TopRight"),
            (x: embeddedMargin, y: menuBarOffset, name: "Embedded-TopLeft"),
            (x: imageWidth - embeddedSize - embeddedMargin, y: imageHeight - embeddedSize - embeddedMargin, name: "Embedded-BottomRight"),
            (x: embeddedMargin, y: imageHeight - embeddedSize - embeddedMargin, name: "Embedded-BottomLeft")
        ]
        
        for pos in embeddedPositions {
            if pos.x >= 0 && pos.y >= 0 && pos.x + embeddedSize <= imageWidth && pos.y + embeddedSize <= imageHeight {
                positions.append(QRPosition(
                    x: pos.x, y: pos.y,
                    width: embeddedSize, height: embeddedSize,
                    name: pos.name, type: .embedded
                ))
            }
        }
        
        // Overlay QR positions (37x37 modules for Version 2, 5x5 pixels per module = 185x185 pixels)
        let overlayPatternSize = 37  // Updated to Version 2 QR code size
        let pixelsPerModule = 5      // Increased pixels per module for better detection
        let overlayPixelSize = overlayPatternSize * pixelsPerModule  // 185 pixels
        let overlayMargin = 15  // Increased margin for larger Version 2 QR codes
        
        let overlayPositions = [
            (x: imageWidth - overlayPixelSize - overlayMargin, y: imageHeight - menuBarOffset - overlayPixelSize, name: "Overlay-TopRight"),
            (x: overlayMargin, y: imageHeight - menuBarOffset - overlayPixelSize, name: "Overlay-TopLeft"),
            (x: imageWidth - overlayPixelSize - overlayMargin, y: overlayMargin, name: "Overlay-BottomRight"),
            (x: overlayMargin, y: overlayMargin, name: "Overlay-BottomLeft")
        ]
        
        for pos in overlayPositions {
            if pos.x >= 0 && pos.y >= 0 && pos.x + overlayPixelSize <= imageWidth && pos.y + overlayPixelSize <= imageHeight {
                positions.append(QRPosition(
                    x: pos.x, y: pos.y,
                    width: overlayPixelSize, height: overlayPixelSize,
                    name: pos.name, type: .overlay
                ))
            }
        }
        
        // Add general watermark pattern regions (128x128 patterns across the image)
        let patternSize = WatermarkConstants.PATTERN_SIZE
        let stepSize = patternSize / 2  // 50% overlap for better coverage
        
        var patternIndex = 0
        for y in stride(from: 0, to: imageHeight - patternSize, by: stepSize) {
            for x in stride(from: 0, to: imageWidth - patternSize, by: stepSize) {
                positions.append(QRPosition(
                    x: x, y: y,
                    width: patternSize, height: patternSize,
                    name: "Pattern-\(patternIndex)", type: .embedded
                ))
                patternIndex += 1
                
                // Limit number of pattern regions to avoid excessive processing
                if patternIndex >= 16 { break }
            }
            if patternIndex >= 16 { break }
        }
        
        return positions
    }
    
    // MARK: - ROI Extraction
    
    private static func extractROI(from image: CGImage, position: QRPosition, verbose: Bool) -> CGImage? {
        // Add padding around the ROI for better context
        let padding = position.type == .overlay ? 20 : 10
        let expandedX = max(0, position.x - padding)
        let expandedY = max(0, position.y - padding)
        let expandedWidth = min(image.width - expandedX, position.width + 2 * padding)
        let expandedHeight = min(image.height - expandedY, position.height + 2 * padding)
        
        let roiRect = CGRect(x: expandedX, y: expandedY, width: expandedWidth, height: expandedHeight)
        
        if verbose {
            print("  ROI extraction: original=(\(position.x),\(position.y)) \(position.width)x\(position.height), expanded=(\(expandedX),\(expandedY)) \(expandedWidth)x\(expandedHeight)")
        }
        
        guard let roiImage = image.cropping(to: roiRect) else {
            if verbose { print("  Failed to crop ROI") }
            return nil
        }
        
        return roiImage
    }
    
    // MARK: - ROI Enhancement Pipeline
    
    private static func enhanceROI(_ roi: CGImage, position: QRPosition, optimizeForQR: Bool, verbose: Bool) -> CGImage? {
        if verbose { print("  Starting enhancement pipeline for \(position.name)...") }
        
        // Step 1: Try blue channel optimization first for QR codes
        if optimizeForQR {
            if let blueChannelResult = enhanceROIBlueChannel(roi, position: position, verbose: verbose) {
                if verbose { print("  Blue channel enhancement successful") }
                return blueChannelResult
            }
            if verbose { print("  Blue channel enhancement failed, falling back to standard pipeline") }
        }
        
        // Fallback to standard grayscale pipeline
        return enhanceROIStandardPipeline(roi, position: position, optimizeForQR: optimizeForQR, verbose: verbose)
    }
    
    private static func enhanceROIBlueChannel(_ roi: CGImage, position: QRPosition, verbose: Bool) -> CGImage? {
        if verbose { print("    Starting blue channel enhancement pipeline...") }
        
        // Step 1: Extract blue channel
        guard let blueChannelROI = extractBlueChannel(roi, verbose: verbose) else {
            if verbose { print("    Failed to extract blue channel") }
            return nil
        }
        
        // Step 2: Enhance blue channel contrast
        guard let contrastEnhancedROI = enhanceBlueChannelContrast(blueChannelROI, verbose: verbose) else {
            if verbose { print("    Failed to enhance blue channel contrast") }
            return nil
        }
        
        // Step 3: Apply blue channel specific preprocessing
        guard let preprocessedROI = applyBlueChannelPreprocessing(contrastEnhancedROI, position: position, verbose: verbose) else {
            if verbose { print("    Failed to apply blue channel preprocessing") }
            return nil
        }
        
        // Step 4: Apply Otsu's threshold optimized for blue channel
        guard let binaryROI = applyOtsuThreshold(preprocessedROI, verbose: verbose) else {
            if verbose { print("    Failed to apply Otsu threshold") }
            return nil
        }
        
        // Step 5: Apply morphological operations optimized for QR patterns
        guard let morphologicalROI = applyQROptimizedMorphology(binaryROI, position: position, verbose: verbose) else {
            if verbose { print("    Failed to apply morphological operations") }
            return nil
        }
        
        // Step 6: Apply QR-specific optimizations
        let qrOptimizedROI = applyQROptimizations(morphologicalROI, position: position, verbose: verbose) ?? morphologicalROI
        
        // Step 7: Upsample for better QR detection
        let scaleFactor = position.type == .overlay ? 4 : 3  // Higher scaling for blue channel enhanced images
        guard let upsampledROI = upsampleImage(qrOptimizedROI, scaleFactor: scaleFactor, verbose: verbose) else {
            if verbose { print("    Failed to upsample blue channel ROI") }
            return nil
        }
        
        if verbose { print("    Blue channel enhancement pipeline completed successfully") }
        return upsampledROI
    }
    
    private static func enhanceROIStandardPipeline(_ roi: CGImage, position: QRPosition, optimizeForQR: Bool, verbose: Bool) -> CGImage? {
        if verbose { print("    Starting standard enhancement pipeline...") }
        
        // Step 1: Convert to grayscale
        guard let grayROI = convertToGrayscale(roi, verbose: verbose) else {
            if verbose { print("    Failed to convert to grayscale") }
            return nil
        }
        
        // Step 2: Apply CLAHE (Contrast Limited Adaptive Histogram Equalization)
        guard let claheROI = applyCLAHE(grayROI, verbose: verbose) else {
            if verbose { print("    Failed to apply CLAHE") }
            return nil
        }
        
        // Step 3: Apply Otsu's threshold
        guard let binaryROI = applyOtsuThreshold(claheROI, verbose: verbose) else {
            if verbose { print("    Failed to apply Otsu threshold") }
            return nil
        }
        
        // Step 4: Apply morphological closing
        guard let closedROI = applyMorphologicalClosing(binaryROI, verbose: verbose) else {
            if verbose { print("    Failed to apply morphological closing") }
            return nil
        }
        
        // Step 5: Apply QR-specific optimizations if enabled
        let processedROI = optimizeForQR ? applyQROptimizations(closedROI, position: position, verbose: verbose) ?? closedROI : closedROI
        
        // Step 6: Upsample for better QR detection
        let scaleFactor = position.type == .overlay ? 3 : 2  // 3x for Version 2 overlay QR (larger base size), 2x for embedded
        guard let upsampledROI = upsampleImage(processedROI, scaleFactor: scaleFactor, verbose: verbose) else {
            if verbose { print("    Failed to upsample ROI") }
            return nil
        }
        
        if verbose { print("    Standard enhancement pipeline completed successfully") }
        return upsampledROI
    }
    
    // MARK: - QR-Specific Optimizations
    
    private static func applyQROptimizations(_ image: CGImage, position: QRPosition, verbose: Bool) -> CGImage? {
        if verbose { print("    Applying QR-specific optimizations...") }
        
        // Apply additional processing specifically for VNDetectBarcodesRequest
        guard let pixelData = extractGrayscalePixelData(from: image) else {
            if verbose { print("    Failed to extract pixel data for QR optimization") }
            return nil
        }
        
        let width = image.width
        let height = image.height
        
        // QR-specific enhancements
        var optimizedData = pixelData
        
        // 1. Enhance finder patterns (7x7 black-white-black squares)
        optimizedData = enhanceFinderPatterns(optimizedData, width: width, height: height, verbose: verbose)
        
        // 2. Improve edge definition for better corner detection
        optimizedData = enhanceEdges(optimizedData, width: width, height: height, verbose: verbose)
        
        // 3. Ensure consistent module sizing
        optimizedData = normalizeModules(optimizedData, width: width, height: height, position: position, verbose: verbose)
        
        return createGrayscaleImage(from: optimizedData, width: width, height: height)
    }
    
    private static func enhanceFinderPatterns(_ data: [UInt8], width: Int, height: Int, verbose: Bool) -> [UInt8] {
        var result = data
        
        // Look for 7x7 patterns that might be QR finder patterns
        let patternSize = 7
        let finderPattern = [
            1,1,1,1,1,1,1,
            1,0,0,0,0,0,1,
            1,0,1,1,1,0,1,
            1,0,1,1,1,0,1,
            1,0,1,1,1,0,1,
            1,0,0,0,0,0,1,
            1,1,1,1,1,1,1
        ]
        
        var finderPatternsFound = 0
        
        for y in 0..<(height - patternSize) {
            for x in 0..<(width - patternSize) {
                var matches = 0
                
                // Check if this region matches a finder pattern
                for py in 0..<patternSize {
                    for px in 0..<patternSize {
                        let dataIndex = (y + py) * width + (x + px)
                        let patternIndex = py * patternSize + px
                        
                        if dataIndex < data.count && patternIndex < finderPattern.count {
                            let expectedValue = finderPattern[patternIndex] * 255
                            let actualValue = Int(data[dataIndex])
                            let threshold = 64  // Tolerance for pattern matching
                            
                            if abs(actualValue - expectedValue) <= threshold {
                                matches += 1
                            }
                        }
                    }
                }
                
                // If most of the pattern matches, enhance it
                let matchRatio = Double(matches) / Double(patternSize * patternSize)
                if matchRatio > 0.7 {
                    finderPatternsFound += 1
                    
                    // Enhance the finder pattern
                    for py in 0..<patternSize {
                        for px in 0..<patternSize {
                            let dataIndex = (y + py) * width + (x + px)
                            let patternIndex = py * patternSize + px
                            
                            if dataIndex < result.count && patternIndex < finderPattern.count {
                                result[dataIndex] = UInt8(finderPattern[patternIndex] * 255)
                            }
                        }
                    }
                }
            }
        }
        
        if verbose && finderPatternsFound > 0 {
            print("      Enhanced \(finderPatternsFound) finder patterns")
        }
        
        return result
    }
    
    private static func enhanceEdges(_ data: [UInt8], width: Int, height: Int, verbose: Bool) -> [UInt8] {
        var result = data
        
        // Apply edge enhancement using a simple sharpening kernel
        let kernel: [Float] = [
            0, -1, 0,
            -1, 5, -1,
            0, -1, 0
        ]
        
        var edgesEnhanced = 0
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var sum: Float = 0
                var kernelIndex = 0
                
                for ky in -1...1 {
                    for kx in -1...1 {
                        let sampleIndex = (y + ky) * width + (x + kx)
                        if sampleIndex < data.count {
                            sum += Float(data[sampleIndex]) * kernel[kernelIndex]
                        }
                        kernelIndex += 1
                    }
                }
                
                let originalValue = Int(data[y * width + x])
                let enhancedValue = Int(max(0, min(255, sum)))
                
                if abs(enhancedValue - originalValue) > 10 {
                    edgesEnhanced += 1
                }
                
                result[y * width + x] = UInt8(enhancedValue)
            }
        }
        
        if verbose && edgesEnhanced > 0 {
            print("      Enhanced \(edgesEnhanced) edge pixels")
        }
        
        return result
    }
    
    private static func normalizeModules(_ data: [UInt8], width: Int, height: Int, position: QRPosition, verbose: Bool) -> [UInt8] {
        // For QR codes, try to normalize the module sizes based on expected QR dimensions
        let expectedModuleSize = position.type == .overlay ? 5 : 2  // Updated for Version 2: 5 pixels per module for overlay
        
        if verbose { print("      Normalizing modules with expected size: \(expectedModuleSize)px") }
        
        var result = data
        
        // Apply a median filter with the expected module size to smooth out noise within modules
        let filterSize = expectedModuleSize
        
        for y in filterSize..<(height - filterSize) {
            for x in filterSize..<(width - filterSize) {
                var values: [UInt8] = []
                
                // Collect values in a square around this pixel
                for dy in -filterSize...filterSize {
                    for dx in -filterSize...filterSize {
                        let sampleIndex = (y + dy) * width + (x + dx)
                        if sampleIndex >= 0 && sampleIndex < data.count {
                            values.append(data[sampleIndex])
                        }
                    }
                }
                
                // Use median value to normalize the module
                values.sort()
                if !values.isEmpty {
                    result[y * width + x] = values[values.count / 2]
                }
            }
        }
        
        return result
    }
    
    // MARK: - Blue Channel Processing Functions
    
    private static func extractBlueChannel(_ image: CGImage, verbose: Bool) -> CGImage? {
        if verbose { print("    Extracting blue channel...") }
        
        guard let pixelData = extractRGBPixelData(from: image) else {
            if verbose { print("    Failed to extract RGB pixel data for blue channel") }
            return nil
        }
        
        let width = image.width
        let height = image.height
        
        // Extract blue channel and create grayscale image
        var blueChannelData = [UInt8](repeating: 0, count: width * height)
        
        for i in 0..<(width * height) {
            let pixelIndex = i * 4
            if pixelIndex + 2 < pixelData.count {
                blueChannelData[i] = pixelData[pixelIndex + 2] // Blue channel
            }
        }
        
        return createGrayscaleImage(from: blueChannelData, width: width, height: height)
    }
    
    private static func enhanceBlueChannelContrast(_ image: CGImage, verbose: Bool) -> CGImage? {
        if verbose { print("    Enhancing blue channel contrast...") }
        
        guard let pixelData = extractGrayscalePixelData(from: image) else {
            if verbose { print("    Failed to extract pixel data for contrast enhancement") }
            return nil
        }
        
        let width = image.width
        let height = image.height
        
        // Calculate histogram for blue channel
        var histogram = [Int](repeating: 0, count: 256)
        for pixel in pixelData {
            histogram[Int(pixel)] += 1
        }
        
        // Find 1st and 99th percentiles for contrast stretching
        let totalPixels = pixelData.count
        let lowerPercentile = findPercentile(histogram: histogram, totalPixels: totalPixels, percentile: 0.01)
        let upperPercentile = findPercentile(histogram: histogram, totalPixels: totalPixels, percentile: 0.99)
        
        if verbose { 
            print("    Blue channel percentiles: 1%=\(lowerPercentile), 99%=\(upperPercentile)") 
        }
        
        // Apply contrast stretching
        let range = upperPercentile - lowerPercentile
        guard range > 0 else { return image }
        
        let enhancedData = pixelData.map { pixel in
            let normalized = max(0, min(255, Int(pixel) - lowerPercentile))
            let stretched = (normalized * 255) / range
            return UInt8(max(0, min(255, stretched)))
        }
        
        return createGrayscaleImage(from: enhancedData, width: width, height: height)
    }
    
    private static func applyBlueChannelPreprocessing(_ image: CGImage, position: QRPosition, verbose: Bool) -> CGImage? {
        if verbose { print("    Applying blue channel specific preprocessing...") }
        
        guard let pixelData = extractGrayscalePixelData(from: image) else {
            if verbose { print("    Failed to extract pixel data for blue channel preprocessing") }
            return nil
        }
        
        let width = image.width
        let height = image.height
        
        // Apply blue channel specific noise reduction
        var preprocessedData = applyBlueChannelNoiseReduction(pixelData, width: width, height: height, verbose: verbose)
        
        // Apply blue channel specific sharpening for QR edge enhancement
        preprocessedData = applyBlueChannelSharpening(preprocessedData, width: width, height: height, verbose: verbose)
        
        // Apply gamma correction optimized for blue channel QR detection
        preprocessedData = applyBlueChannelGammaCorrection(preprocessedData, verbose: verbose)
        
        return createGrayscaleImage(from: preprocessedData, width: width, height: height)
    }
    
    private static func applyBlueChannelNoiseReduction(_ data: [UInt8], width: Int, height: Int, verbose: Bool) -> [UInt8] {
        if verbose { print("      Applying blue channel noise reduction...") }
        
        var result = data
        
        // Apply bilateral filter for edge-preserving smoothing
        for y in 2..<(height - 2) {
            for x in 2..<(width - 2) {
                let centerIndex = y * width + x
                let centerValue = Double(data[centerIndex])
                
                var weightedSum: Double = 0
                var totalWeight: Double = 0
                
                // 5x5 bilateral filter
                for dy in -2...2 {
                    for dx in -2...2 {
                        let neighborIndex = (y + dy) * width + (x + dx)
                        if neighborIndex >= 0 && neighborIndex < data.count {
                            let neighborValue = Double(data[neighborIndex])
                            
                            // Spatial weight (Gaussian)
                            let spatialDistance = Double(dx * dx + dy * dy)
                            let spatialWeight = exp(-spatialDistance / (2.0 * 1.5 * 1.5))
                            
                            // Intensity weight
                            let intensityDifference = abs(centerValue - neighborValue)
                            let intensityWeight = exp(-intensityDifference / (2.0 * 20.0 * 20.0))
                            
                            let totalWeightValue = spatialWeight * intensityWeight
                            weightedSum += neighborValue * totalWeightValue
                            totalWeight += totalWeightValue
                        }
                    }
                }
                
                if totalWeight > 0 {
                    result[centerIndex] = UInt8(max(0, min(255, weightedSum / totalWeight)))
                }
            }
        }
        
        return result
    }
    
    private static func applyBlueChannelSharpening(_ data: [UInt8], width: Int, height: Int, verbose: Bool) -> [UInt8] {
        if verbose { print("      Applying blue channel sharpening...") }
        
        var result = data
        
        // Unsharp mask for blue channel QR edge enhancement
        let kernel: [Float] = [
            0, -1, 0,
            -1, 6, -1,
            0, -1, 0
        ]
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var sum: Float = 0
                var kernelIndex = 0
                
                for ky in -1...1 {
                    for kx in -1...1 {
                        let sampleIndex = (y + ky) * width + (x + kx)
                        if sampleIndex < data.count {
                            sum += Float(data[sampleIndex]) * kernel[kernelIndex]
                        }
                        kernelIndex += 1
                    }
                }
                
                let sharpenedValue = max(0, min(255, Int(sum)))
                result[y * width + x] = UInt8(sharpenedValue)
            }
        }
        
        return result
    }
    
    private static func applyBlueChannelGammaCorrection(_ data: [UInt8], verbose: Bool) -> [UInt8] {
        if verbose { print("      Applying blue channel gamma correction...") }
        
        // Gamma correction optimized for blue channel QR detection
        let gamma: Double = 0.8  // Slightly brighten midtones for better QR contrast
        
        return data.map { pixel in
            let normalized = Double(pixel) / 255.0
            let corrected = pow(normalized, gamma)
            return UInt8(max(0, min(255, corrected * 255)))
        }
    }
    
    private static func applyQROptimizedMorphology(_ image: CGImage, position: QRPosition, verbose: Bool) -> CGImage? {
        if verbose { print("    Applying QR-optimized morphological operations...") }
        
        guard let pixelData = extractGrayscalePixelData(from: image) else {
            if verbose { print("    Failed to extract pixel data for morphological operations") }
            return nil
        }
        
        let width = image.width
        let height = image.height
        
        // Use smaller kernel for QR patterns to preserve fine details
        let kernelSize = position.type == .overlay ? 2 : 1
        
        // Apply opening (erosion followed by dilation) to remove noise
        let erodedData = applyErosion(pixelData, width: width, height: height, kernelSize: kernelSize)
        let openedData = applyDilation(erodedData, width: width, height: height, kernelSize: kernelSize)
        
        // Apply closing (dilation followed by erosion) to fill gaps
        let dilatedData = applyDilation(openedData, width: width, height: height, kernelSize: kernelSize)
        let closedData = applyErosion(dilatedData, width: width, height: height, kernelSize: kernelSize)
        
        return createGrayscaleImage(from: closedData, width: width, height: height)
    }
    
    private static func findPercentile(histogram: [Int], totalPixels: Int, percentile: Double) -> Int {
        let targetCount = Int(Double(totalPixels) * percentile)
        var count = 0
        
        for (value, freq) in histogram.enumerated() {
            count += freq
            if count >= targetCount {
                return value
            }
        }
        
        return 255
    }
    
    private static func extractRGBPixelData(from image: CGImage) -> [UInt8]? {
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
    
    // MARK: - Image Processing Functions
    
    private static func convertToGrayscale(_ image: CGImage, verbose: Bool) -> CGImage? {
        if verbose { print("    Converting to grayscale...") }
        
        let width = image.width
        let height = image.height
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        
        guard let ctx = context else {
            if verbose { print("    Failed to create grayscale context") }
            return nil
        }
        
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return ctx.makeImage()
    }
    
    private static func applyCLAHE(_ image: CGImage, verbose: Bool) -> CGImage? {
        if verbose { print("    Applying CLAHE (Contrast Limited Adaptive Histogram Equalization)...") }
        
        guard let pixelData = extractGrayscalePixelData(from: image) else {
            if verbose { print("    Failed to extract pixel data for CLAHE") }
            return nil
        }
        
        let width = image.width
        let height = image.height
        
        // CLAHE parameters
        let tileSize = 8  // 8x8 tiles
        let clipLimit: Float = 2.0  // Contrast limiting factor
        
        let enhancedData = applyCLAHEToPixelData(pixelData, width: width, height: height, 
                                               tileSize: tileSize, clipLimit: clipLimit, verbose: verbose)
        
        return createGrayscaleImage(from: enhancedData, width: width, height: height)
    }
    
    private static func applyCLAHEToPixelData(_ data: [UInt8], width: Int, height: Int, 
                                           tileSize: Int, clipLimit: Float, verbose: Bool) -> [UInt8] {
        var result = data
        
        let tilesX = (width + tileSize - 1) / tileSize
        let tilesY = (height + tileSize - 1) / tileSize
        
        if verbose { print("      CLAHE processing \(tilesX)x\(tilesY) tiles of size \(tileSize)x\(tileSize)") }
        
        // Process each tile
        for tileY in 0..<tilesY {
            for tileX in 0..<tilesX {
                let startX = tileX * tileSize
                let startY = tileY * tileSize
                let endX = min(startX + tileSize, width)
                let endY = min(startY + tileSize, height)
                
                // Extract tile histogram
                var histogram = [Int](repeating: 0, count: 256)
                for y in startY..<endY {
                    for x in startX..<endX {
                        let index = y * width + x
                        if index < data.count {
                            histogram[Int(data[index])] += 1
                        }
                    }
                }
                
                // Apply contrast limiting
                let totalPixels = (endX - startX) * (endY - startY)
                let averageHeight = Float(totalPixels) / 256.0
                let clipHeight = Int(averageHeight * clipLimit)
                
                var excessPixels = 0
                for i in 0..<256 {
                    if histogram[i] > clipHeight {
                        excessPixels += histogram[i] - clipHeight
                        histogram[i] = clipHeight
                    }
                }
                
                // Redistribute excess pixels uniformly
                let redistribution = excessPixels / 256
                for i in 0..<256 {
                    histogram[i] += redistribution
                }
                
                // Create cumulative distribution
                var cdf = [Float](repeating: 0, count: 256)
                cdf[0] = Float(histogram[0])
                for i in 1..<256 {
                    cdf[i] = cdf[i-1] + Float(histogram[i])
                }
                
                // Normalize CDF
                let maxCDF = cdf[255]
                if maxCDF > 0 {
                    for i in 0..<256 {
                        cdf[i] = (cdf[i] / maxCDF) * 255.0
                    }
                }
                
                // Apply histogram equalization to tile
                for y in startY..<endY {
                    for x in startX..<endX {
                        let index = y * width + x
                        if index < result.count {
                            let originalValue = Int(data[index])
                            result[index] = UInt8(max(0, min(255, cdf[originalValue])))
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private static func applyOtsuThreshold(_ image: CGImage, verbose: Bool) -> CGImage? {
        if verbose { print("    Applying Otsu's threshold...") }
        
        guard let pixelData = extractGrayscalePixelData(from: image) else {
            if verbose { print("    Failed to extract pixel data for Otsu threshold") }
            return nil
        }
        
        let width = image.width
        let height = image.height
        
        // Calculate histogram
        var histogram = [Int](repeating: 0, count: 256)
        for pixel in pixelData {
            histogram[Int(pixel)] += 1
        }
        
        // Find optimal threshold using Otsu's method
        let threshold = calculateOtsuThreshold(histogram: histogram, totalPixels: pixelData.count, verbose: verbose)
        
        if verbose { print("      Otsu threshold calculated: \(threshold)") }
        
        // Apply threshold
        let binaryData = pixelData.map { pixel in
            return pixel >= threshold ? UInt8(255) : UInt8(0)
        }
        
        return createGrayscaleImage(from: binaryData, width: width, height: height)
    }
    
    private static func calculateOtsuThreshold(histogram: [Int], totalPixels: Int, verbose: Bool) -> UInt8 {
        var maxVariance: Float = 0
        var optimalThreshold: UInt8 = 127
        
        for threshold in 0..<256 {
            // Calculate class probabilities
            var weight1 = 0
            var weight2 = 0
            var sum1: Float = 0
            var sum2: Float = 0
            
            for i in 0..<256 {
                if i <= threshold {
                    weight1 += histogram[i]
                    sum1 += Float(i * histogram[i])
                } else {
                    weight2 += histogram[i]
                    sum2 += Float(i * histogram[i])
                }
            }
            
            guard weight1 > 0 && weight2 > 0 else { continue }
            
            let mean1 = sum1 / Float(weight1)
            let mean2 = sum2 / Float(weight2)
            let betweenClassVariance = Float(weight1 * weight2) * pow(mean1 - mean2, 2) / Float(totalPixels * totalPixels)
            
            if betweenClassVariance > maxVariance {
                maxVariance = betweenClassVariance
                optimalThreshold = UInt8(threshold)
            }
        }
        
        return optimalThreshold
    }
    
    private static func applyMorphologicalClosing(_ image: CGImage, verbose: Bool) -> CGImage? {
        if verbose { print("    Applying morphological closing...") }
        
        guard let pixelData = extractGrayscalePixelData(from: image) else {
            if verbose { print("    Failed to extract pixel data for morphological operations") }
            return nil
        }
        
        let width = image.width
        let height = image.height
        
        // Apply dilation followed by erosion (closing)
        let dilatedData = applyDilation(pixelData, width: width, height: height, kernelSize: 3)
        let closedData = applyErosion(dilatedData, width: width, height: height, kernelSize: 3)
        
        return createGrayscaleImage(from: closedData, width: width, height: height)
    }
    
    private static func applyDilation(_ data: [UInt8], width: Int, height: Int, kernelSize: Int) -> [UInt8] {
        var result = data
        let radius = kernelSize / 2
        
        for y in radius..<(height - radius) {
            for x in radius..<(width - radius) {
                var maxValue: UInt8 = 0
                
                for ky in -radius...radius {
                    for kx in -radius...radius {
                        let sampleIndex = (y + ky) * width + (x + kx)
                        if sampleIndex >= 0 && sampleIndex < data.count {
                            maxValue = max(maxValue, data[sampleIndex])
                        }
                    }
                }
                
                let index = y * width + x
                if index < result.count {
                    result[index] = maxValue
                }
            }
        }
        
        return result
    }
    
    private static func applyErosion(_ data: [UInt8], width: Int, height: Int, kernelSize: Int) -> [UInt8] {
        var result = data
        let radius = kernelSize / 2
        
        for y in radius..<(height - radius) {
            for x in radius..<(width - radius) {
                var minValue: UInt8 = 255
                
                for ky in -radius...radius {
                    for kx in -radius...radius {
                        let sampleIndex = (y + ky) * width + (x + kx)
                        if sampleIndex >= 0 && sampleIndex < data.count {
                            minValue = min(minValue, data[sampleIndex])
                        }
                    }
                }
                
                let index = y * width + x
                if index < result.count {
                    result[index] = minValue
                }
            }
        }
        
        return result
    }
    
    private static func upsampleImage(_ image: CGImage, scaleFactor: Int, verbose: Bool) -> CGImage? {
        if verbose { print("    Upsampling by \(scaleFactor)x...") }
        
        let originalWidth = image.width
        let originalHeight = image.height
        let newWidth = originalWidth * scaleFactor
        let newHeight = originalHeight * scaleFactor
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        
        guard let ctx = context else {
            if verbose { print("    Failed to create upsampling context") }
            return nil
        }
        
        // Use nearest neighbor interpolation for crisp edges
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        if verbose { print("    Upsampled from \(originalWidth)x\(originalHeight) to \(newWidth)x\(newHeight)") }
        
        return ctx.makeImage()
    }
    
    // MARK: - Helper Functions
    
    private static func extractGrayscalePixelData(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let totalBytes = width * height
        
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        
        guard let ctx = context else { return nil }
        
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return pixelData
    }
    
    private static func createGrayscaleImage(from pixelData: [UInt8], width: Int, height: Int) -> CGImage? {
        let bytesPerRow = width
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        return pixelData.withUnsafeBytes { bytes in
            let context = CGContext(
                data: UnsafeMutableRawPointer(mutating: bytes.baseAddress),
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )
            
            return context?.makeImage()
        }
    }
}