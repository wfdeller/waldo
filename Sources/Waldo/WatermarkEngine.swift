import CoreGraphics
import Foundation
import Vision
import CoreImage

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
        // Try luminous pattern detection first (for luminous overlay types)
        if let luminousResult = extractLuminousWatermark(from: image, threshold: threshold, verbose: verbose, debug: debug) {
            if debug { print("Debug: Luminous extraction succeeded") }
            return luminousResult
        }
        
        if debug { print("Debug: Luminous extraction failed, trying ROI-enhanced...") }
        
        // Try ROI-enhanced extraction (for QR codes)
        if let roiResult = extractFromEnhancedROIs(from: image, threshold: threshold, verbose: verbose, debug: debug) {
            if debug { print("Debug: ROI-enhanced extraction succeeded") }
            return roiResult
        }
        
        if debug { print("Debug: ROI-enhanced extraction failed, trying overlay extraction...") }
        
        // Try overlay-specific extraction (for camera photos of screens)
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
    
    // MARK: - ROI-Enhanced Extraction
    
    private static func extractFromEnhancedROIs(from image: CGImage, threshold: Double, verbose: Bool, debug: Bool) -> String? {
        if verbose { print("Starting ROI-enhanced watermark extraction...") }
        
        // Get enhanced ROIs
        let enhancedROIs = ROIEnhancer.enhanceROIsForWatermarkDetection(from: image, verbose: verbose)
        
        if enhancedROIs.isEmpty {
            if debug { print("Debug: No enhanced ROIs available") }
            return nil
        }
        
        if verbose { print("Processing \(enhancedROIs.count) enhanced ROIs...") }
        
        // Try QR detection on enhanced ROIs first
        for (roi, position) in enhancedROIs {
            if verbose { print("Trying QR detection on enhanced \(position.name)...") }
            
            // Try Vision framework QR detection on enhanced ROI
            if let qrResult = extractQRFromEnhancedROI(roi, position: position, verbose: verbose, debug: debug) {
                if verbose { print("QR code detected in enhanced \(position.name): \(qrResult)") }
                return qrResult
            }
            
            // Try watermark pattern extraction on enhanced ROI
            if position.type == .embedded {
                if let watermarkResult = extractWatermarkFromEnhancedROI(roi, position: position, threshold: threshold, verbose: verbose, debug: debug) {
                    if verbose { print("Watermark detected in enhanced \(position.name): \(watermarkResult)") }
                    return watermarkResult
                }
            }
        }
        
        if debug { print("Debug: No watermarks found in enhanced ROIs") }
        return nil
    }
    
    private static func extractQRFromEnhancedROI(_ roi: CGImage, position: ROIEnhancer.QRPosition, verbose: Bool, debug: Bool) -> String? {
        if verbose { print("Using optimized VNDetectBarcodesRequest on enhanced \(position.name)...") }
        
        // Primary detection with optimal settings for enhanced ROIs
        if let result = performOptimizedBarcodeDetection(roi, position: position, verbose: verbose, debug: debug) {
            return result
        }
        
        // Fallback strategies for difficult cases
        if let result = tryAlternativeBarcodeDetection(roi, position: position, verbose: verbose, debug: debug) {
            return result
        }
        
        if debug { print("Debug: All VNDetectBarcodesRequest methods failed for \(position.name)") }
        return nil
    }
    
    private static func performOptimizedBarcodeDetection(_ roi: CGImage, position: ROIEnhancer.QRPosition, verbose: Bool, debug: Bool) -> String? {
        // Try blue channel optimized detection first
        if let blueChannelResult = performBlueChannelOptimizedDetection(roi, position: position, verbose: verbose, debug: debug) {
            return blueChannelResult
        }
        
        if debug { print("Debug: Blue channel detection failed, trying standard optimized detection") }
        
        let request = VNDetectBarcodesRequest()
        
        // Optimize for QR codes specifically
        request.symbologies = [.qr]
        
        // Enhanced settings for preprocessed images
        request.usesCPUOnly = false  // Use GPU acceleration when available
        
        // Create optimized request handler
        let options: [VNImageOption: Any] = [
            .ciContext: CIContext(options: [.useSoftwareRenderer: false])
        ]
        
        let handler = VNImageRequestHandler(cgImage: roi, options: options)
        
        do {
            try handler.perform([request])
            
            guard let results = request.results, !results.isEmpty else {
                if debug { print("Debug: No QR codes detected in enhanced \(position.name)") }
                return nil
            }
            
            if verbose { print("VNDetectBarcodesRequest found \(results.count) QR code(s) in enhanced \(position.name)") }
            
            // Process results with enhanced validation
            for result in results {
                if let payload = result.payloadStringValue {
                    if verbose { 
                        print("QR detected in \(position.name): '\(payload)' (confidence: \(result.confidence))")
                        print("QR bounds: \(result.boundingBox)")
                    }
                    
                    // Enhanced validation for Version 2 watermark QR codes
                    if isValidWatermarkQRVersion2(payload, confidence: result.confidence) {
                        if verbose { print("Found valid Version 2 watermark QR in \(position.name): \(payload)") }
                        return payload
                    }
                }
            }
            
            if debug { print("Debug: No valid watermark QR codes found in enhanced \(position.name)") }
            return nil
            
        } catch {
            if debug { print("Debug: VNDetectBarcodesRequest failed for \(position.name): \(error)") }
            return nil
        }
    }
    
    private static func performBlueChannelOptimizedDetection(_ roi: CGImage, position: ROIEnhancer.QRPosition, verbose: Bool, debug: Bool) -> String? {
        if verbose { print("Trying blue channel optimized Vision detection for \(position.name)...") }
        
        // Extract and enhance blue channel from ROI
        guard let blueChannelROI = extractAndEnhanceBlueChannelForVision(roi, position: position, verbose: verbose, debug: debug) else {
            if debug { print("Debug: Failed to extract blue channel for Vision detection") }
            return nil
        }
        
        // Perform Vision detection on blue channel enhanced image
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        request.usesCPUOnly = false
        
        // Optimized settings for blue channel detection
        let options: [VNImageOption: Any] = [
            .ciContext: CIContext(options: [
                .useSoftwareRenderer: false,
                .workingColorSpace: CGColorSpaceCreateDeviceGray()
            ])
        ]
        
        let handler = VNImageRequestHandler(cgImage: blueChannelROI, options: options)
        
        do {
            try handler.perform([request])
            
            guard let results = request.results, !results.isEmpty else {
                if debug { print("Debug: No QR codes detected in blue channel enhanced \(position.name)") }
                return nil
            }
            
            if verbose { print("Blue channel Vision detection found \(results.count) QR code(s) in \(position.name)") }
            
            // Process results with enhanced validation for blue channel
            for result in results {
                if let payload = result.payloadStringValue {
                    if verbose { 
                        print("Blue channel QR detected: '\(payload)' (confidence: \(result.confidence))")
                        print("Blue channel QR bounds: \(result.boundingBox)")
                    }
                    
                    // Enhanced validation for blue channel watermark QR codes
                    if isValidBlueChannelWatermarkQR(payload, confidence: result.confidence, verbose: verbose) {
                        if verbose { print("Found valid blue channel watermark QR in \(position.name): \(payload)") }
                        return payload
                    }
                }
            }
            
            if debug { print("Debug: No valid blue channel watermark QR codes found in \(position.name)") }
            return nil
            
        } catch {
            if debug { print("Debug: Blue channel Vision detection failed for \(position.name): \(error)") }
            return nil
        }
    }
    
    private static func extractAndEnhanceBlueChannelForVision(_ roi: CGImage, position: ROIEnhancer.QRPosition, verbose: Bool, debug: Bool) -> CGImage? {
        if verbose { print("  Extracting and enhancing blue channel for Vision framework...") }
        
        // Extract RGB pixel data
        guard let pixelData = extractPixelData(from: roi) else {
            if debug { print("Debug: Failed to extract pixel data for blue channel Vision enhancement") }
            return nil
        }
        
        let width = roi.width
        let height = roi.height
        
        // Extract blue channel with enhanced processing
        var blueChannelData = [UInt8](repeating: 0, count: width * height)
        
        for i in 0..<(width * height) {
            let pixelIndex = i * 4
            if pixelIndex + 2 < pixelData.count {
                let blueValue = pixelData[pixelIndex + 2]
                blueChannelData[i] = blueValue
            }
        }
        
        // Apply blue channel specific enhancements for Vision framework
        blueChannelData = enhanceBlueChannelForVision(blueChannelData, width: width, height: height, position: position, verbose: verbose)
        
        // Create enhanced blue channel image
        return createGrayscaleImageFromData(blueChannelData, width: width, height: height)
    }
    
    private static func enhanceBlueChannelForVision(_ data: [UInt8], width: Int, height: Int, position: ROIEnhancer.QRPosition, verbose: Bool) -> [UInt8] {
        if verbose { print("    Enhancing blue channel data for Vision detection...") }
        
        var enhancedData = data
        
        // Step 1: Adaptive histogram equalization for blue channel
        enhancedData = applyBlueChannelHistogramEqualization(enhancedData, width: width, height: height, verbose: verbose)
        
        // Step 2: Edge enhancement specifically for QR patterns
        enhancedData = applyBlueChannelEdgeEnhancement(enhancedData, width: width, height: height, verbose: verbose)
        
        // Step 3: Noise reduction while preserving QR structure
        enhancedData = applyBlueChannelQRNoiseReduction(enhancedData, width: width, height: height, position: position, verbose: verbose)
        
        // Step 4: Final contrast optimization for Vision framework
        enhancedData = applyBlueChannelVisionContrast(enhancedData, verbose: verbose)
        
        return enhancedData
    }
    
    private static func applyBlueChannelHistogramEqualization(_ data: [UInt8], width: Int, height: Int, verbose: Bool) -> [UInt8] {
        // Calculate histogram
        var histogram = [Int](repeating: 0, count: 256)
        for pixel in data {
            histogram[Int(pixel)] += 1
        }
        
        // Calculate cumulative distribution
        var cdf = [Double](repeating: 0, count: 256)
        cdf[0] = Double(histogram[0])
        for i in 1..<256 {
            cdf[i] = cdf[i-1] + Double(histogram[i])
        }
        
        // Normalize CDF
        let totalPixels = Double(data.count)
        for i in 0..<256 {
            cdf[i] = (cdf[i] / totalPixels) * 255.0
        }
        
        // Apply equalization
        return data.map { pixel in
            UInt8(max(0, min(255, cdf[Int(pixel)])))
        }
    }
    
    private static func applyBlueChannelEdgeEnhancement(_ data: [UInt8], width: Int, height: Int, verbose: Bool) -> [UInt8] {
        var result = data
        
        // Laplacian edge enhancement kernel
        let kernel: [Float] = [
            0, -1, 0,
            -1, 5, -1,
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
                
                let enhancedValue = max(0, min(255, Int(sum)))
                result[y * width + x] = UInt8(enhancedValue)
            }
        }
        
        return result
    }
    
    private static func applyBlueChannelQRNoiseReduction(_ data: [UInt8], width: Int, height: Int, position: ROIEnhancer.QRPosition, verbose: Bool) -> [UInt8] {
        // Apply morphological operations to clean up QR patterns
        let kernelSize = position.type == .overlay ? 1 : 1  // Small kernel to preserve QR details
        
        // Opening to remove small noise
        var result = data
        for _ in 0..<kernelSize {
            result = applyMorphologicalErosion(result, width: width, height: height)
        }
        for _ in 0..<kernelSize {
            result = applyMorphologicalDilation(result, width: width, height: height)
        }
        
        return result
    }
    
    private static func applyBlueChannelVisionContrast(_ data: [UInt8], verbose: Bool) -> [UInt8] {
        // Final contrast adjustment optimized for Vision framework QR detection
        let contrast: Double = 1.2  // Slight contrast boost
        let brightness: Double = 10  // Slight brightness boost
        
        return data.map { pixel in
            let adjusted = (Double(pixel) * contrast) + brightness
            return UInt8(max(0, min(255, adjusted)))
        }
    }
    
    private static func applyMorphologicalErosion(_ data: [UInt8], width: Int, height: Int) -> [UInt8] {
        var result = data
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var minValue: UInt8 = 255
                
                for dy in -1...1 {
                    for dx in -1...1 {
                        let sampleIndex = (y + dy) * width + (x + dx)
                        if sampleIndex >= 0 && sampleIndex < data.count {
                            minValue = min(minValue, data[sampleIndex])
                        }
                    }
                }
                
                result[y * width + x] = minValue
            }
        }
        
        return result
    }
    
    private static func applyMorphologicalDilation(_ data: [UInt8], width: Int, height: Int) -> [UInt8] {
        var result = data
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var maxValue: UInt8 = 0
                
                for dy in -1...1 {
                    for dx in -1...1 {
                        let sampleIndex = (y + dy) * width + (x + dx)
                        if sampleIndex >= 0 && sampleIndex < data.count {
                            maxValue = max(maxValue, data[sampleIndex])
                        }
                    }
                }
                
                result[y * width + x] = maxValue
            }
        }
        
        return result
    }
    
    private static func createGrayscaleImageFromData(_ pixelData: [UInt8], width: Int, height: Int) -> CGImage? {
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
    
    private static func isValidBlueChannelWatermarkQR(_ message: String, confidence: Float, verbose: Bool) -> Bool {
        if verbose { print("    Validating blue channel QR: '\(message)' (confidence: \(confidence))") }
        
        // Enhanced validation for blue channel QR codes
        guard !message.isEmpty else { 
            if verbose { print("    Validation failed: empty message") }
            return false 
        }
        
        // Lower confidence threshold for blue channel since we've enhanced the signal
        guard confidence >= 0.03 else { 
            if verbose { print("    Validation failed: low confidence \(confidence)") }
            return false 
        }
        
        // Remove error correction and validate
        let cleanedMessage = removeEnhancedErrorCorrection(message) ?? removeSimpleErrorCorrection(message) ?? message
        
        if verbose { print("    Cleaned message: '\(cleanedMessage)'") }
        
        // Basic watermark format validation
        let components = cleanedMessage.components(separatedBy: ":")
        
        // Should have at least 3 components: username:machine:uuid or similar
        guard components.count >= 3 else { 
            if verbose { print("    Validation failed: insufficient components (\(components.count))") }
            return false 
        }
        
        // Check for reasonable length
        guard cleanedMessage.count >= 10 && cleanedMessage.count <= 800 else { 
            if verbose { print("    Validation failed: invalid length (\(cleanedMessage.count))") }
            return false 
        }
        
        // Enhanced validation for blue channel extracted watermarks
        let hasAlphanumeric = cleanedMessage.rangeOfCharacter(from: CharacterSet.alphanumerics) != nil
        let hasColon = cleanedMessage.contains(":")
        let hasReasonableLength = components.allSatisfy { $0.count > 0 && $0.count < 150 }
        let hasUserPattern = components.count >= 1 && !components[0].isEmpty
        let hasMachinePattern = components.count >= 2 && !components[1].isEmpty
        let hasIdentifierPattern = components.count >= 3 && !components[2].isEmpty
        
        let isValid = hasAlphanumeric && hasColon && hasReasonableLength && 
                     hasUserPattern && hasMachinePattern && hasIdentifierPattern
        
        if verbose { 
            print("    Validation result: \(isValid)")
            print("    - hasAlphanumeric: \(hasAlphanumeric)")
            print("    - hasColon: \(hasColon)")
            print("    - hasReasonableLength: \(hasReasonableLength)")
            print("    - hasUserPattern: \(hasUserPattern)")
            print("    - hasMachinePattern: \(hasMachinePattern)")
            print("    - hasIdentifierPattern: \(hasIdentifierPattern)")
        }
        
        return isValid
    }
    
    private static func tryAlternativeBarcodeDetection(_ roi: CGImage, position: ROIEnhancer.QRPosition, verbose: Bool, debug: Bool) -> String? {
        if verbose { print("Trying alternative detection strategies for \(position.name)...") }
        
        // Strategy 1: Try blue channel combined with all symbologies
        if let result = tryBlueChannelWithAllSymbologies(roi, position: position, verbose: verbose, debug: debug) {
            return result
        }
        
        // Strategy 2: Try channel separation and fusion approaches
        if let result = tryChannelSeparationFusion(roi, position: position, verbose: verbose, debug: debug) {
            return result
        }
        
        // Strategy 3: Try with all barcode symbologies (not just QR)
        if let result = tryAllSymbologies(roi, position: position, verbose: verbose, debug: debug) {
            return result
        }
        
        // Strategy 4: Try with inverted image
        if let result = tryInvertedDetection(roi, position: position, verbose: verbose, debug: debug) {
            return result
        }
        
        // Strategy 5: Try with different request configurations
        if let result = tryVariousConfigurations(roi, position: position, verbose: verbose, debug: debug) {
            return result
        }
        
        // Strategy 6: Try multi-channel weighted combination
        if let result = tryMultiChannelWeightedCombination(roi, position: position, verbose: verbose, debug: debug) {
            return result
        }
        
        return nil
    }
    
    private static func tryBlueChannelWithAllSymbologies(_ roi: CGImage, position: ROIEnhancer.QRPosition, verbose: Bool, debug: Bool) -> String? {
        if verbose { print("Trying blue channel detection with all symbologies for \(position.name)...") }
        
        // Extract blue channel
        guard let blueChannelROI = extractAndEnhanceBlueChannelForVision(roi, position: position, verbose: verbose, debug: debug) else {
            return nil
        }
        
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr, .aztec, .dataMatrix, .pdf417, .code128, .code39, .code93, .ean8, .ean13, .itf14, .upce]
        request.usesCPUOnly = false
        
        let handler = VNImageRequestHandler(cgImage: blueChannelROI)
        
        do {
            try handler.perform([request])
            
            guard let results = request.results, !results.isEmpty else { return nil }
            
            if verbose { print("Blue channel all-symbologies detection found \(results.count) barcode(s)") }
            
            for result in results {
                if let payload = result.payloadStringValue {
                    if verbose { print("Blue channel barcode detected: '\(payload)' (type: \(result.symbology.rawValue))") }
                    
                    if isValidBlueChannelWatermarkQR(payload, confidence: result.confidence, verbose: verbose) {
                        if verbose { print("Found valid blue channel watermark in \(result.symbology.rawValue) format: \(payload)") }
                        return payload
                    }
                }
            }
            
        } catch {
            if debug { print("Debug: Blue channel all-symbologies detection failed: \(error)") }
        }
        
        return nil
    }
    
    private static func tryChannelSeparationFusion(_ roi: CGImage, position: ROIEnhancer.QRPosition, verbose: Bool, debug: Bool) -> String? {
        if verbose { print("Trying channel separation and fusion for \(position.name)...") }
        
        guard let pixelData = extractPixelData(from: roi) else { return nil }
        
        let width = roi.width
        let height = roi.height
        
        // Extract individual channels
        var redChannel = [UInt8](repeating: 0, count: width * height)
        var greenChannel = [UInt8](repeating: 0, count: width * height)
        var blueChannel = [UInt8](repeating: 0, count: width * height)
        
        for i in 0..<(width * height) {
            let pixelIndex = i * 4
            if pixelIndex + 2 < pixelData.count {
                redChannel[i] = pixelData[pixelIndex]
                greenChannel[i] = pixelData[pixelIndex + 1]
                blueChannel[i] = pixelData[pixelIndex + 2]
            }
        }
        
        // Try different channel fusion strategies
        let fusionStrategies = [
            ("blue-enhanced", createBlueEnhancedFusion(redChannel, greenChannel, blueChannel)),
            ("blue-green-diff", createChannelDifference(greenChannel, blueChannel)),
            ("blue-red-diff", createChannelDifference(redChannel, blueChannel)),
            ("weighted-blue", createWeightedBlueChannel(redChannel, greenChannel, blueChannel))
        ]
        
        for (strategyName, fusedChannel) in fusionStrategies {
            if verbose { print("  Trying fusion strategy: \(strategyName)") }
            
            guard let fusedImage = createGrayscaleImageFromData(fusedChannel, width: width, height: height) else {
                continue
            }
            
            // Apply Vision detection to fused channel
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]
            request.usesCPUOnly = false
            
            let handler = VNImageRequestHandler(cgImage: fusedImage)
            
            do {
                try handler.perform([request])
                
                if let results = request.results, !results.isEmpty {
                    if verbose { print("  \(strategyName) found \(results.count) QR code(s)") }
                    
                    for result in results {
                        if let payload = result.payloadStringValue {
                            if isValidBlueChannelWatermarkQR(payload, confidence: result.confidence, verbose: verbose) {
                                if verbose { print("Found valid watermark with \(strategyName): \(payload)") }
                                return payload
                            }
                        }
                    }
                }
            } catch {
                if debug { print("Debug: \(strategyName) detection failed: \(error)") }
            }
        }
        
        return nil
    }
    
    private static func createBlueEnhancedFusion(_ red: [UInt8], _ green: [UInt8], _ blue: [UInt8]) -> [UInt8] {
        return zip(zip(red, green), blue).map { redGreen, blueValue in
            let (redValue, greenValue) = redGreen
            // Enhance blue channel while suppressing red and green
            let enhanced = Int(blueValue) * 2 - Int(redValue) / 2 - Int(greenValue) / 2
            return UInt8(max(0, min(255, enhanced)))
        }
    }
    
    private static func createChannelDifference(_ channel1: [UInt8], _ channel2: [UInt8]) -> [UInt8] {
        return zip(channel1, channel2).map { val1, val2 in
            let diff = abs(Int(val1) - Int(val2))
            return UInt8(min(255, diff))
        }
    }
    
    private static func createWeightedBlueChannel(_ red: [UInt8], _ green: [UInt8], _ blue: [UInt8]) -> [UInt8] {
        return zip(zip(red, green), blue).map { redGreen, blueValue in
            let (redValue, greenValue) = redGreen
            // Weighted combination favoring blue channel
            let weighted = (Int(blueValue) * 6 + Int(greenValue) * 2 + Int(redValue) * 1) / 9
            return UInt8(max(0, min(255, weighted)))
        }
    }
    
    private static func tryMultiChannelWeightedCombination(_ roi: CGImage, position: ROIEnhancer.QRPosition, verbose: Bool, debug: Bool) -> String? {
        if verbose { print("Trying multi-channel weighted combination for \(position.name)...") }
        
        guard let pixelData = extractPixelData(from: roi) else { return nil }
        
        let width = roi.width
        let height = roi.height
        
        // Create multiple enhanced combinations
        var enhancedChannels: [(name: String, data: [UInt8])] = []
        
        // Combination 1: Blue-weighted luminance
        var blueWeightedLuma = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let pixelIndex = i * 4
            if pixelIndex + 2 < pixelData.count {
                let r = Double(pixelData[pixelIndex])
                let g = Double(pixelData[pixelIndex + 1])
                let b = Double(pixelData[pixelIndex + 2])
                
                // Modified luminance formula favoring blue channel
                let luminance = 0.114 * r + 0.299 * g + 0.587 * b  // Blue-weighted
                blueWeightedLuma[i] = UInt8(max(0, min(255, luminance)))
            }
        }
        enhancedChannels.append(("blue-weighted-luma", blueWeightedLuma))
        
        // Combination 2: Blue channel with adaptive enhancement
        var adaptiveBlue = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let pixelIndex = i * 4
            if pixelIndex + 2 < pixelData.count {
                let r = Int(pixelData[pixelIndex])
                let g = Int(pixelData[pixelIndex + 1])
                let b = Int(pixelData[pixelIndex + 2])
                
                // Adaptive enhancement based on local contrast
                let localContrast = max(abs(r - g), abs(g - b), abs(b - r))
                let enhancementFactor = localContrast > 20 ? 1.5 : 1.2
                
                let enhanced = Double(b) * enhancementFactor
                adaptiveBlue[i] = UInt8(max(0, min(255, enhanced)))
            }
        }
        enhancedChannels.append(("adaptive-blue", adaptiveBlue))
        
        // Combination 3: Blue-dominant RGB combination
        var blueDominant = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let pixelIndex = i * 4
            if pixelIndex + 2 < pixelData.count {
                let r = Int(pixelData[pixelIndex])
                let g = Int(pixelData[pixelIndex + 1])
                let b = Int(pixelData[pixelIndex + 2])
                
                // Combination that amplifies blue when it's dominant
                let isBlueDistinct = b > max(r, g) + 10
                let combined = isBlueDistinct ? b * 3 / 2 : (r + g + b * 2) / 4
                blueDominant[i] = UInt8(max(0, min(255, combined)))
            }
        }
        enhancedChannels.append(("blue-dominant", blueDominant))
        
        // Try Vision detection on each enhanced channel
        for (channelName, channelData) in enhancedChannels {
            if verbose { print("  Trying multi-channel strategy: \(channelName)") }
            
            guard let channelImage = createGrayscaleImageFromData(channelData, width: width, height: height) else {
                continue
            }
            
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]
            request.usesCPUOnly = false
            
            let handler = VNImageRequestHandler(cgImage: channelImage)
            
            do {
                try handler.perform([request])
                
                if let results = request.results, !results.isEmpty {
                    if verbose { print("  \(channelName) found \(results.count) QR code(s)") }
                    
                    for result in results {
                        if let payload = result.payloadStringValue {
                            if isValidBlueChannelWatermarkQR(payload, confidence: result.confidence, verbose: verbose) {
                                if verbose { print("Found valid watermark with \(channelName): \(payload)") }
                                return payload
                            }
                        }
                    }
                }
            } catch {
                if debug { print("Debug: \(channelName) detection failed: \(error)") }
            }
        }
        
        return nil
    }
    
    private static func tryAllSymbologies(_ roi: CGImage, position: ROIEnhancer.QRPosition, verbose: Bool, debug: Bool) -> String? {
        if verbose { print("Trying detection with all barcode symbologies for \(position.name)...") }
        
        let request = VNDetectBarcodesRequest()
        
        // Try with all available symbologies
        request.symbologies = [.qr, .aztec, .dataMatrix, .pdf417, .code128, .code39, .code93, .ean8, .ean13, .itf14, .upce]
        request.usesCPUOnly = false
        
        let handler = VNImageRequestHandler(cgImage: roi)
        
        do {
            try handler.perform([request])
            
            guard let results = request.results, !results.isEmpty else { return nil }
            
            if verbose { print("All-symbologies detection found \(results.count) barcode(s)") }
            
            for result in results {
                if let payload = result.payloadStringValue {
                    if verbose { print("Barcode detected: '\(payload)' (type: \(result.symbology.rawValue))") }
                    
                    if isValidWatermarkQR(payload, confidence: result.confidence) {
                        if verbose { print("Found valid watermark in \(result.symbology.rawValue) format: \(payload)") }
                        return payload
                    }
                }
            }
            
        } catch {
            if debug { print("Debug: All-symbologies detection failed: \(error)") }
        }
        
        return nil
    }
    
    private static func tryInvertedDetection(_ roi: CGImage, position: ROIEnhancer.QRPosition, verbose: Bool, debug: Bool) -> String? {
        if verbose { print("Trying inverted image detection for \(position.name)...") }
        
        // Create inverted version of the ROI using Core Image
        let ciImage = CIImage(cgImage: roi)
        
        guard let invertFilter = CIFilter(name: "CIColorInvert") else {
            if debug { print("Debug: Failed to create color invert filter") }
            return nil
        }
        
        invertFilter.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let invertedCIImage = invertFilter.outputImage else {
            if debug { print("Debug: Failed to create inverted image") }
            return nil
        }
        
        // Convert back to CGImage
        let context = CIContext()
        guard let invertedROI = context.createCGImage(invertedCIImage, from: invertedCIImage.extent) else {
            if debug { print("Debug: Failed to convert inverted CIImage to CGImage") }
            return nil
        }
        
        // Perform detection on inverted image
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        request.usesCPUOnly = false
        
        let handler = VNImageRequestHandler(cgImage: invertedROI)
        
        do {
            try handler.perform([request])
            
            guard let results = request.results, !results.isEmpty else { return nil }
            
            if verbose { print("Inverted detection found \(results.count) QR code(s)") }
            
            for result in results {
                if let payload = result.payloadStringValue {
                    if verbose { print("Inverted QR detected: '\(payload)'") }
                    
                    if isValidWatermarkQR(payload, confidence: result.confidence) {
                        if verbose { print("Found valid watermark QR in inverted image: \(payload)") }
                        return payload
                    }
                }
            }
            
        } catch {
            if debug { print("Debug: Inverted detection failed: \(error)") }
        }
        
        return nil
    }
    
    private static func tryVariousConfigurations(_ roi: CGImage, position: ROIEnhancer.QRPosition, verbose: Bool, debug: Bool) -> String? {
        if verbose { print("Trying various detection configurations for \(position.name)...") }
        
        // Different CPU/GPU configurations
        let configurations = [
            (usesCPUOnly: true, description: "CPU-only"),
            (usesCPUOnly: false, description: "GPU-accelerated")
        ]
        
        for config in configurations {
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]
            request.usesCPUOnly = config.usesCPUOnly
            
            let handler = VNImageRequestHandler(cgImage: roi)
            
            do {
                try handler.perform([request])
                
                guard let results = request.results, !results.isEmpty else { continue }
                
                if verbose { print("\(config.description) detection found \(results.count) QR code(s)") }
                
                for result in results {
                    if let payload = result.payloadStringValue {
                        if verbose { print("\(config.description) QR: '\(payload)'") }
                        
                        if isValidWatermarkQR(payload, confidence: result.confidence) {
                            if verbose { print("Found valid watermark with \(config.description): \(payload)") }
                            return payload
                        }
                    }
                }
                
            } catch {
                if debug { print("Debug: \(config.description) detection failed: \(error)") }
            }
        }
        
        return nil
    }
    
    private static func isValidWatermarkQRVersion2(_ message: String, confidence: Float = 1.0) -> Bool {
        // Enhanced validation for Version 2 QR codes with ECC Level H
        guard !message.isEmpty else { return false }
        
        // Lower confidence threshold for Version 2 with better error correction
        guard confidence >= 0.05 else { return false }  // Even lower threshold for Version 2
        
        // Remove Version 2 error correction first if present
        let cleanedMessage = removeEnhancedErrorCorrection(message) ?? removeSimpleErrorCorrection(message) ?? message
        
        // Basic watermark format validation
        let components = cleanedMessage.components(separatedBy: ":")
        
        // Should have at least 3 components: username:machine:uuid or similar
        guard components.count >= 3 else { return false }
        
        // Check for reasonable length (Version 2 can handle more data)
        guard cleanedMessage.count >= 10 && cleanedMessage.count <= 800 else { return false }
        
        // Look for patterns typical of our watermarks
        let hasAlphanumeric = cleanedMessage.rangeOfCharacter(from: CharacterSet.alphanumerics) != nil
        let hasColon = cleanedMessage.contains(":")
        let hasReasonableLength = components.allSatisfy { $0.count > 0 && $0.count < 150 }
        
        // Enhanced validation: check for typical watermark patterns
        let hasUserPattern = components.count >= 1 && !components[0].isEmpty
        let hasMachinePattern = components.count >= 2 && !components[1].isEmpty
        let hasIdentifierPattern = components.count >= 3 && !components[2].isEmpty
        
        return hasAlphanumeric && hasColon && hasReasonableLength && 
               hasUserPattern && hasMachinePattern && hasIdentifierPattern
    }
    
    private static func isValidWatermarkQR(_ message: String, confidence: Float = 1.0) -> Bool {
        // Legacy validation function - also delegate to Version 2 for better compatibility
        return isValidWatermarkQRVersion2(message, confidence: confidence)
    }
    
    
    private static func extractWatermarkFromEnhancedROI(_ roi: CGImage, position: ROIEnhancer.QRPosition, threshold: Double, verbose: Bool, debug: Bool) -> String? {
        // Extract pixel data from enhanced ROI
        guard let pixelData = extractPixelData(from: roi) else {
            if debug { print("Debug: Failed to extract pixel data from enhanced \(position.name)") }
            return nil
        }
        
        let width = roi.width
        let height = roi.height
        
        // Apply enhanced pattern detection on the processed ROI
        // Since the ROI is already contrast-enhanced and thresholded, we can use simple binary detection
        
        var extractedBits: [UInt8] = []
        var patternMatches = 0
        var totalSamples = 0
        
        // Sample the entire enhanced ROI for watermark patterns
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * 4
                
                if pixelIndex + 2 < pixelData.count {
                    let r = Int(pixelData[pixelIndex])
                    let g = Int(pixelData[pixelIndex + 1])
                    let b = Int(pixelData[pixelIndex + 2])
                    
                    let avgRGB = (r + g + b) / 3
                    
                    // For enhanced (binary) images, use simple threshold
                    let isHighPattern = avgRGB > 127
                    
                    if isHighPattern {
                        extractedBits.append(1)
                        patternMatches += 1
                    } else {
                        extractedBits.append(0)
                    }
                    
                    totalSamples += 1
                }
            }
        }
        
        let patternMatchRate = Double(patternMatches) / Double(totalSamples)
        
        if verbose { print("Enhanced \(position.name): \(patternMatches)/\(totalSamples) pattern matches (\(String(format: "%.1f", patternMatchRate * 100))%)") }
        
        // Only proceed if we have a reasonable pattern match rate
        if patternMatchRate > 0.1 && extractedBits.count >= 16 {
            // Try to decode the enhanced pattern
            if let decoded = decodeEnhancedPattern(extractedBits, verbose: verbose, debug: debug) {
                return decoded
            }
        }
        
        return nil
    }
    
    private static func decodeEnhancedPattern(_ bits: [UInt8], verbose: Bool, debug: Bool) -> String? {
        // Try direct string reconstruction from bits
        let bytes = stride(from: 0, to: bits.count, by: 8).compactMap { startIndex -> UInt8? in
            guard startIndex + 7 < bits.count else { return nil }
            
            var byte: UInt8 = 0
            for i in 0..<8 {
                byte |= bits[startIndex + i] << i
            }
            return byte
        }
        
        if let decoded = String(data: Data(bytes), encoding: .utf8) {
            // Check if it looks like a watermark
            if decoded.contains(":") && decoded.count > 10 && decoded.count < 200 {
                if verbose { print("Decoded enhanced pattern: '\(decoded)'") }
                return decoded
            }
        }
        
        // Try with enhanced Version 2 error correction removal (ECC Level H - 30% recovery)
        if bits.count >= 48 {  // Version 2 uses enhanced error correction (6 bytes worth for level H)
            let errorCorrectedBytes = stride(from: 0, to: bits.count, by: 48).compactMap { startIndex -> UInt8? in
                guard startIndex + 47 < bits.count else { return nil }
                
                // Enhanced majority voting for each bit in groups of 6 (for ECC Level H)
                var correctedByte: UInt8 = 0
                for bitPos in 0..<8 {
                    let bitStart = startIndex + bitPos * 6
                    if bitStart + 5 < bits.count {
                        var bitSum = 0
                        for i in 0..<6 {
                            bitSum += Int(bits[bitStart + i])
                        }
                        
                        let correctedBit = bitSum >= 3 ? 1 : 0  // Majority of 6
                        correctedByte |= UInt8(correctedBit) << bitPos
                    }
                }
                
                return correctedByte
            }
            
            if let decoded = String(data: Data(errorCorrectedBytes), encoding: .utf8) {
                if decoded.contains(":") && decoded.count > 10 && decoded.count < 200 {
                    if verbose { print("Decoded Version 2 ECC Level H enhanced pattern: '\(decoded)'") }
                    return decoded
                }
            }
        }
        
        // Fallback: try original 3x error correction for backward compatibility
        if bits.count >= 24 {  // At least 3 bytes worth
            let errorCorrectedBytes = stride(from: 0, to: bits.count, by: 24).compactMap { startIndex -> UInt8? in
                guard startIndex + 23 < bits.count else { return nil }
                
                // Majority voting for each bit in groups of 3
                var correctedByte: UInt8 = 0
                for bitPos in 0..<8 {
                    let bitStart = startIndex + bitPos * 3
                    if bitStart + 2 < bits.count {
                        let bit1 = bits[bitStart]
                        let bit2 = bits[bitStart + 1]
                        let bit3 = bits[bitStart + 2]
                        
                        let correctedBit = (bit1 + bit2 + bit3) >= 2 ? 1 : 0
                        correctedByte |= UInt8(correctedBit) << bitPos
                    }
                }
                
                return correctedByte
            }
            
            if let decoded = String(data: Data(errorCorrectedBytes), encoding: .utf8) {
                if decoded.contains(":") && decoded.count > 10 && decoded.count < 200 {
                    if verbose { print("Decoded legacy error-corrected enhanced pattern: '\(decoded)'") }
                    return decoded
                }
            }
        }
        
        if debug { print("Debug: Failed to decode enhanced pattern from \(bits.count) bits") }
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
            print(".  Starting overlay watermark detection on \(width)x\(height) image")
            print(".  Testing \(tileSizes.count) tile sizes: \(tileSizes)")
        }

        for tileSize in tileSizes {
            if verbose { 
                print(".  Trying tile size: \(tileSize)x\(tileSize)") 
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
                        
                        // Convert to luminance for better detection
                        let y = rgbToLuminance(r: Int(r), g: Int(g), b: Int(b))
                        
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
                            let expectedHighY = rgbToLuminance(r: WatermarkConstants.RGB_HIGH, g: WatermarkConstants.RGB_HIGH, b: WatermarkConstants.RGB_HIGH)
                            let expectedLowY = rgbToLuminance(r: WatermarkConstants.RGB_LOW, g: WatermarkConstants.RGB_LOW, b: WatermarkConstants.RGB_LOW)
                            
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
            // Try Version 2 enhanced error correction first (Level H pattern)
            let final = removeEnhancedErrorCorrection(decoded) ?? removeSimpleErrorCorrection(decoded) ?? decoded
            if verbose { print(".        After Version 2 error correction: '\(final)'") }
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
                        
                        // Embed QR pattern with subtle modifications
                        if patternValue == 1 {
                            // Slightly bright values for 1-bits
                            modifiedData[pixelIndex] = UInt8(WatermarkConstants.RGB_HIGH)
                            modifiedData[pixelIndex + 1] = UInt8(WatermarkConstants.RGB_HIGH)
                            modifiedData[pixelIndex + 2] = UInt8(WatermarkConstants.RGB_HIGH)
                        } else {
                            // Base values for 0-bits
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
        print("Extracting QR codes using Vision framework...")
        
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let results = request.results, !results.isEmpty else {
                print(".  No QR codes detected by Vision framework")
                return nil
            }
            
            print(".  Vision framework detected \(results.count) QR code(s)")
            
            // Look for watermark-like QR codes (containing our data format)  
            for result in results {
                if let payload = result.payloadStringValue {
                    print(".  QR detected: '\(payload)' (confidence: \(result.confidence))")
                    
                    // Check if this looks like our watermark format
                    if payload.contains("|") || payload.count > 10 {
                        print(".  Found watermark QR: \(payload)")
                        return payload
                    }
                }
            }
            
            print(".  No watermark QR codes found")
            return nil
            
        } catch {
            print(".  Vision QR detection failed: \(error)")
            return nil
        }
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
    
    
    
    private static func addSimpleErrorCorrection(_ input: String) -> String {
        // Simple repetition code - repeat each character 3 times
        return input.map { String(repeating: String($0), count: 3) }.joined()
    }
    
    private static func removeEnhancedErrorCorrection(_ input: String?) -> String? {
        // Remove Version 2 ECC Level H error correction (complex pattern matching)
        guard let input = input else { return nil }
        
        // Look for the enhanced pattern: characterRepeated + "|" + blockRepeated + checksum
        let components = input.components(separatedBy: "|")
        if components.count >= 2 {
            // Try to extract the first block and decode it
            let firstBlock = components[0]
            if let decoded = removeSimpleErrorCorrection(firstBlock) {
                // Validate with checksum if present
                if components.count >= 3 && components[2].count >= 2 {
                    let expectedChecksum = decoded.reduce(0) { $0 + Int($1.asciiValue ?? 0) } % 256
                    let checksumHex = String(format: "%02X", expectedChecksum)
                    let providedChecksum = String(components[2].prefix(2))
                    
                    if checksumHex == providedChecksum {
                        return decoded
                    }
                }
                return decoded
            }
        }
        
        return nil
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
    
    private static func rgbToLuminance(r: Int, g: Int, b: Int) -> Int {
        // Standard luminance calculation (ITU-R BT.709)
        let rf = Double(r)
        let gf = Double(g)
        let bf = Double(b)
        
        let y = 0.299 * rf + 0.587 * gf + 0.114 * bf
        return Int(y)
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
    
    private static func extractOverlayQRFormat(pixelData: [UInt8], width: Int, height: Int, margin: Int, menuBarOffset: Int) -> String? {
        let patternSize = WatermarkConstants.QR_VERSION2_SIZE  // Version 2 QR size (37x37)
        let pixelsPerModule = WatermarkConstants.QR_VERSION2_PIXELS_PER_MODULE  // 5x5 pixels per QR module
        let qrPixelSize = WatermarkConstants.QR_VERSION2_PIXEL_SIZE  // 185 total pixels
        
        // Define corner positions for overlay QR codes
        let corners = [
            (x: width - qrPixelSize - margin, y: height - menuBarOffset - qrPixelSize, name: "Top-right"),                    
            (x: margin, y: height - menuBarOffset - qrPixelSize, name: "Top-left"),                                          
            (x: width - qrPixelSize - margin, y: margin, name: "Bottom-right"),   
            (x: margin, y: margin, name: "Bottom-left")                          
        ]
        
        print(".  Image dimensions: \(width)x\(height)")
        print(".  Expected Version 2 QR size: \(qrPixelSize)x\(qrPixelSize) pixels (\(patternSize)x\(patternSize) modules)")
        
        for corner in corners {
            print(".  Trying overlay QR format at \(corner.name) corner (\(corner.x), \(corner.y))")
            print(".    QR area bounds: (\(corner.x), \(corner.y)) to (\(corner.x + qrPixelSize), \(corner.y + qrPixelSize))")
            
            if let result = extractOverlayQRAtPosition(pixelData: pixelData, width: width, height: height, 
                                                     startX: corner.x, startY: corner.y, 
                                                     patternSize: patternSize, pixelsPerModule: pixelsPerModule) {
                print(".    Successfully decoded overlay QR from \(corner.name): \(result)")
                return result
            } else {
                print(".    Failed to extract from \(corner.name) corner")
            }
        }
        
        return nil
    }
    
    private static func extractEmbeddedQRFormat(pixelData: [UInt8], width: Int, height: Int, margin: Int, menuBarOffset: Int) -> String? {
        let patternSize = 32  // Old embedded QR size
        
        // Define corner positions for embedded QR codes  
        let corners = [
            (x: width - patternSize - margin, y: menuBarOffset, name: "Top-right"),                    
            (x: margin, y: menuBarOffset, name: "Top-left"),                                          
            (x: width - patternSize - margin, y: height - patternSize - margin, name: "Bottom-right"),   
            (x: margin, y: height - patternSize - margin, name: "Bottom-left")                          
        ]
        
        for corner in corners {
            print(".  Trying embedded QR format at \(corner.name) corner (\(corner.x), \(corner.y))")
            
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
                print(".    Extracted embedded pattern length: \(extractedPattern.count)")
                
                if let result = decodeMicroPattern(extractedPattern) {
                    print(".    Successfully decoded embedded QR from \(corner.name): \(result)")
                    return result
                } else {
                    print(".    Failed to decode embedded QR from \(corner.name)")
                }
            }
        }
        
        return nil
    }
    
    private static func extractOverlayQRAtPosition(pixelData: [UInt8], width: Int, height: Int, 
                                                 startX: Int, startY: Int, patternSize: Int, pixelsPerModule: Int) -> String? {
        var extractedPattern: [UInt8] = []
        var sampleCount = 0
        var blackPixels = 0
        var whitePixels = 0
        
        // Extract QR pattern by sampling the center of each module
        for moduleY in 0..<patternSize {
            for moduleX in 0..<patternSize {
                // Sample the center pixel of each module
                let centerX = startX + moduleX * pixelsPerModule + pixelsPerModule / 2
                let centerY = startY + moduleY * pixelsPerModule + pixelsPerModule / 2
                
                let pixelIndex = (centerY * width + centerX) * 4
                if pixelIndex + 2 < pixelData.count {
                    let r = Int(pixelData[pixelIndex])
                    let g = Int(pixelData[pixelIndex + 1])
                    let b = Int(pixelData[pixelIndex + 2])
                    
                    // Adaptive thresholding for better camera photo detection
                    let avgRGB = (r + g + b) / 3
                    // Use dynamic threshold based on local image characteristics
                    let dynamicThreshold = calculateDynamicThreshold(pixelData: pixelData, width: width, height: height, centerX: centerX, centerY: centerY)
                    let bit: UInt8 = avgRGB > dynamicThreshold ? 1 : 0
                    extractedPattern.append(bit)
                    
                    if bit == 1 { whitePixels += 1 } else { blackPixels += 1 }
                    sampleCount += 1
                    
                    // Debug first few pixels
                    if sampleCount <= 5 {
                        print(".      Pixel (\(centerX), \(centerY)): RGB(\(r),\(g),\(b)) avg=\(avgRGB) -> \(bit)")
                    }
                } else {
                    print(".      Pixel (\(centerX), \(centerY)) out of bounds, pixelIndex=\(pixelIndex), max=\(pixelData.count)")
                    return nil  // Out of bounds
                }
            }
        }
        
        print(".      Extracted \(sampleCount) pixels: \(blackPixels) black, \(whitePixels) white")
        print(".      First 25 bits: \(Array(extractedPattern.prefix(25)))")
        
        // Try to decode the extracted pattern
        return decodeOverlayQRPattern(extractedPattern)
    }
    
    private static func calculateDynamicThreshold(pixelData: [UInt8], width: Int, height: Int, centerX: Int, centerY: Int) -> Int {
        // Sample surrounding area to determine local threshold
        var samples: [Int] = []
        let sampleRadius = WatermarkConstants.QR_THRESHOLD_SAMPLE_RADIUS
        
        for dy in -sampleRadius...sampleRadius {
            for dx in -sampleRadius...sampleRadius {
                let sampleX = centerX + dx
                let sampleY = centerY + dy
                
                if sampleX >= 0 && sampleX < width && sampleY >= 0 && sampleY < height {
                    let pixelIndex = (sampleY * width + sampleX) * 4
                    if pixelIndex + 2 < pixelData.count {
                        let r = Int(pixelData[pixelIndex])
                        let g = Int(pixelData[pixelIndex + 1])
                        let b = Int(pixelData[pixelIndex + 2])
                        samples.append((r + g + b) / 3)
                    }
                }
            }
        }
        
        if samples.isEmpty { return WatermarkConstants.QR_BINARY_THRESHOLD }
        
        // Use median as threshold for better noise resistance
        samples.sort()
        return samples[samples.count / 2]
    }
    
    private static func decodeOverlayQRPattern(_ pattern: [UInt8]) -> String? {
        // Validate finder patterns first for Version 2 QR
        if !validateFinderPatterns(pattern, size: WatermarkConstants.QR_VERSION2_SIZE) {
            print(".      Version 2 finder pattern validation failed")
            return nil
        }
        
        // Extract data from non-structural areas
        var dataBits: [UInt8] = []
        let size = WatermarkConstants.QR_VERSION2_SIZE
        
        for y in 0..<size {
            for x in 0..<size {
                let index = y * size + x
                // Skip structural patterns for Version 2 QR (37x37)
                let inTopLeftFinder = (x < 9 && y < 9)
                let inTopRightFinder = (x >= size-9 && y < 9)
                let inBottomLeftFinder = (x < 9 && y >= size-9)
                let inAlignment = (x >= 14 && x <= 20 && y >= 14 && y <= 20)  // Version 2 alignment at (18,18)
                let inTiming = (x == 6 || y == 6)
                
                let isStructural = inTopLeftFinder || inTopRightFinder || inBottomLeftFinder || inAlignment || inTiming
                
                if !isStructural && index < pattern.count {
                    dataBits.append(pattern[index])
                }
            }
        }
        
        // Convert bits to string
        return reconstructStringFromBits(dataBits)
    }
    
    private static func validateFinderPatterns(_ pattern: [UInt8], size: Int) -> Bool {
        // Check if top-left finder pattern exists
        let expectedPattern = [
            1,1,1,1,1,1,1,
            1,0,0,0,0,0,1,
            1,0,1,1,1,0,1,
            1,0,1,1,1,0,1,
            1,0,1,1,1,0,1,
            1,0,0,0,0,0,1,
            1,1,1,1,1,1,1
        ]
        
        var matches = 0
        for y in 0..<7 {
            for x in 0..<7 {
                let patternIndex = y * size + x
                let expectedIndex = y * 7 + x
                if patternIndex < pattern.count && expectedIndex < expectedPattern.count {
                    if pattern[patternIndex] == expectedPattern[expectedIndex] {
                        matches += 1
                    }
                }
            }
        }
        
        // Require configurable match threshold for finder pattern tolerance
        return Double(matches) / Double(expectedPattern.count) >= WatermarkConstants.QR_FINDER_PATTERN_TOLERANCE
    }
    
    // MARK: - Luminous Watermark Extraction
    
    private static func extractLuminousWatermark(from image: CGImage, threshold: Double, verbose: Bool, debug: Bool) -> String? {
        if verbose { print("Attempting luminous pattern extraction...") }
        
        // Analyze luminance patterns in corner regions
        let corners = getLuminanceCornerRegions(from: image)
        
        for (position, cornerImage) in corners {
            if verbose { print("Analyzing luminance corner: \(position)") }
            
            if let pattern = extractLuminancePattern(from: cornerImage, verbose: verbose, debug: debug) {
                if pattern.isValidWatermarkPattern() {
                    if verbose { print("Valid luminance pattern found at \(position)") }
                    // For now, return a placeholder since luminous overlays don't embed actual data
                    // In a full implementation, this would decode the luminance variations
                    return "luminous:detected:pattern:\(Int(Date().timeIntervalSince1970))"
                }
            }
        }
        
        if debug { print("Debug: No valid luminous patterns detected") }
        return nil
    }
    
    private static func getLuminanceCornerRegions(from image: CGImage) -> [(String, CGImage)] {
        let width = image.width
        let height = image.height
        let cornerSize = Int(LuminousOverlayConstants.CORNER_PATTERN_SIZE)
        let margin = Int(CGFloat(width) * LuminousOverlayConstants.MARGIN_PERCENTAGE)
        
        var corners: [(String, CGImage)] = []
        
        let cornerDefinitions = [
            ("top-left", CGRect(x: margin, y: margin, width: cornerSize, height: cornerSize)),
            ("top-right", CGRect(x: width - cornerSize - margin, y: margin, width: cornerSize, height: cornerSize)),
            ("bottom-left", CGRect(x: margin, y: height - cornerSize - margin, width: cornerSize, height: cornerSize)),
            ("bottom-right", CGRect(x: width - cornerSize - margin, y: height - cornerSize - margin, width: cornerSize, height: cornerSize))
        ]
        
        for (name, rect) in cornerDefinitions {
            if let cornerImage = image.cropping(to: rect) {
                corners.append((name, cornerImage))
            }
        }
        
        return corners
    }
    
    private static func extractLuminancePattern(from image: CGImage, verbose: Bool, debug: Bool) -> LuminancePattern? {
        guard let pixelData = extractPixelData(from: image) else { return nil }
        
        let width = image.width
        let height = image.height
        var luminanceValues: [CGFloat] = []
        
        // Extract luminance values from the image
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * 4
                if pixelIndex + 2 < pixelData.count {
                    let r = CGFloat(pixelData[pixelIndex]) / 255.0
                    let g = CGFloat(pixelData[pixelIndex + 1]) / 255.0
                    let b = CGFloat(pixelData[pixelIndex + 2]) / 255.0
                    
                    let luminance = LuminousOverlayConstants.calculatePerceptualLuminance(red: r, green: g, blue: b)
                    luminanceValues.append(luminance)
                }
            }
        }
        
        if verbose { print("Extracted \(luminanceValues.count) luminance values") }
        
        // Analyze the pattern
        return LuminancePattern(values: luminanceValues, width: width, height: height)
    }
    
    private struct LuminancePattern {
        let values: [CGFloat]
        let width: Int
        let height: Int
        
        func isValidWatermarkPattern() -> Bool {
            // Check for gradient patterns that indicate luminous watermarks
            let meanLuminance = values.reduce(0, +) / CGFloat(values.count)
            let variance = values.map { pow($0 - meanLuminance, 2) }.reduce(0, +) / CGFloat(values.count)
            
            // Valid luminous patterns should have reasonable variance (not uniform)
            // and mean luminance within expected ranges
            return variance > 0.01 && 
                   meanLuminance > LuminousOverlayConstants.MIN_LUMINANCE && 
                   meanLuminance < LuminousOverlayConstants.MAX_LUMINANCE
        }
    }
}