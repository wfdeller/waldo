import CoreGraphics
import Foundation
import UniformTypeIdentifiers
import ImageIO

class PhotoProcessor {
    
    static func loadImage(from url: URL, logger: Logger = Logger()) -> CGImage? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        logger.debug("Attempting to load image from: \(url.path)")
        
        // Check file existence and permissions
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            logger.debug("File does not exist: \(url.path)")
            return nil
        }
        
        // Check file size
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                logger.debug("File size: \(fileSize) bytes")
                if fileSize == 0 {
                    logger.debug("File is empty")
                    return nil
                }
                if fileSize > 100_000_000 { // 100MB limit
                    logger.debug("File too large: \(fileSize) bytes (limit: 100MB)")
                }
            }
        } catch {
            logger.debug("Failed to read file attributes: \(error.localizedDescription)")
        }
        
        // Validate file type
        guard let fileType = UTType(filenameExtension: url.pathExtension) else {
            logger.debug("Unknown file extension: \(url.pathExtension)")
            return nil
        }
        
        guard fileType.conforms(to: .image) else {
            logger.debug("File is not an image type: \(fileType.identifier)")
            return nil
        }
        
        logger.debug("File type validated: \(fileType.identifier)")
        
        // Create image source
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            logger.debug("Failed to create CGImageSource from URL")
            return nil
        }
        
        // Get image properties
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            logger.debug("Image properties: \(properties)")
            
            if let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int,
               let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int {
                logger.debug("Image dimensions: \(pixelWidth)x\(pixelHeight)")
            }
            
            if let colorModel = properties[kCGImagePropertyColorModel as String] as? String {
                logger.debug("Color model: \(colorModel)")
            }
            
            if let hasAlpha = properties[kCGImagePropertyHasAlpha as String] as? Bool {
                logger.debug("Has alpha channel: \(hasAlpha)")
            }
        }
        
        // Create the image
        guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            logger.debug("Failed to create CGImage from source")
            return nil
        }
        
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        logger.timing("Image loading", duration: loadTime)
        logger.debug("Successfully loaded image: \(image.width)x\(image.height)")
        
        return image
    }
    
    static func loadImage(from data: Data, logger: Logger = Logger()) -> CGImage? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        logger.debug("Attempting to load image from data (\(data.count) bytes)")
        
        guard !data.isEmpty else {
            logger.debug("Data is empty")
            return nil
        }
        
        if data.count > 100_000_000 { // 100MB limit
            logger.debug("Data too large: \(data.count) bytes (limit: 100MB)")
        }
        
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            logger.debug("Failed to create CGImageSource from data")
            return nil
        }
        
        // Get image properties
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            logger.debug("Image properties from data: \(properties)")
            
            if let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int,
               let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int {
                logger.debug("Image dimensions from data: \(pixelWidth)x\(pixelHeight)")
            }
        }
        
        guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            logger.debug("Failed to create CGImage from data source")
            return nil
        }
        
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        logger.timing("Image loading from data", duration: loadTime)
        logger.debug("Successfully loaded image from data: \(image.width)x\(image.height)")
        
        return image
    }
    
    static func extractWatermarkFromPhoto(at url: URL, threshold: Double = WatermarkConstants.PHOTO_CONFIDENCE_THRESHOLD, verbose: Bool = false, debug: Bool = false, enableScreenDetection: Bool = true, simpleExtraction: Bool = false) -> (userID: String, watermark: String, timestamp: TimeInterval)? {
        let logger = Logger(verbose: verbose, debug: debug)
        
        guard let image = loadImage(from: url, logger: logger) else {
            logger.error("Failed to load image from: \(url)")
            return nil
        }
        
        if verbose {
            print("Original image size: \(image.width)x\(image.height)")
        }
        
        // Try screen detection and perspective correction first
        var processedImage = image
        if enableScreenDetection {
            if let correctedImage = ScreenDetector.detectAndCorrectScreen(from: image, verbose: verbose) {
                if verbose {
                    print("Screen detected and corrected, new size: \(correctedImage.width)x\(correctedImage.height)")
                }
                processedImage = correctedImage
            } else {
                if verbose {
                    print("No screen detected, proceeding with original image")
                }
            }
        } else {
            if verbose {
                print("Screen detection disabled, proceeding with original image")
            }
        }
        
        // Choose extraction method based on simpleExtraction flag
        if simpleExtraction {
            if debug {
                print("Debug: Using simple LSB steganography extraction only")
            }
            // Go directly to LSB steganography for digital screenshots
            if let stegoResult = SteganographyEngine.extractWatermark(from: processedImage) {
                if debug {
                    print("Debug: Simple steganography extraction succeeded")
                }
                return stegoResult
            }
        } else {
            // Try robust extraction first (for camera photos) - ROI enhancement is now enabled by default
            if let robustResult = WatermarkEngine.extractPhotoResistantWatermark(from: processedImage, threshold: threshold, verbose: verbose, debug: debug) {
                return parseWatermark(robustResult)
            }
            
            if debug {
                print("Debug: Robust extraction failed, trying steganography fallback...")
            }
            
            // Fall back to original steganography (for digital screenshots)  
            if let stegoResult = SteganographyEngine.extractWatermark(from: processedImage) {
                if debug {
                    print("Debug: Steganography extraction succeeded")
                }
                return stegoResult
            }
        }
        
        if debug {
            print("Debug: All extraction methods failed")
            print("Debug: Processed image size: \(processedImage.width)x\(processedImage.height)")
            print("Debug: Threshold used: \(threshold)")
        }
        
        return nil
    }
    
    static func extractWatermarkFromPhotoData(_ data: Data, threshold: Double = WatermarkConstants.PHOTO_CONFIDENCE_THRESHOLD, verbose: Bool = false, debug: Bool = false, enableScreenDetection: Bool = true) -> (userID: String, watermark: String, timestamp: TimeInterval)? {
        let logger = Logger(verbose: verbose, debug: debug)
        
        guard let image = loadImage(from: data, logger: logger) else {
            logger.error("Failed to load image from data")
            return nil
        }
        
        // Try screen detection and perspective correction first
        var processedImage = image
        if enableScreenDetection {
            if let correctedImage = ScreenDetector.detectAndCorrectScreen(from: image, verbose: verbose) {
                if verbose {
                    print("Screen detected and corrected from data, new size: \(correctedImage.width)x\(correctedImage.height)")
                }
                processedImage = correctedImage
            } else {
                if verbose {
                    print("No screen detected in data, proceeding with original image")
                }
            }
        } else {
            if verbose {
                print("Screen detection disabled for data, proceeding with original image")
            }
        }
        
        // Try robust extraction first (for camera photos) - ROI enhancement is now enabled by default
        if let robustResult = WatermarkEngine.extractPhotoResistantWatermark(from: processedImage, threshold: threshold, verbose: verbose, debug: debug) {
            return parseWatermark(robustResult)
        }
        
        // Fall back to original steganography (for digital screenshots)
        return SteganographyEngine.extractWatermark(from: processedImage)
    }
    
    private static func parseWatermark(_ watermarkString: String) -> (userID: String, watermark: String, timestamp: TimeInterval)? {
        let components = watermarkString.components(separatedBy: ":")
        
        guard components.count >= 4,
              let timestamp = TimeInterval(components.last!) else {
            return nil
        }
        
        let userID = components[0]
        let watermark = components[1..<components.count-1].joined(separator: ":")
        
        // Validate watermark format and content
        guard isValidWatermark(userID: userID, watermark: watermark, timestamp: timestamp) else {
            return nil
        }
        
        return (userID: userID, watermark: watermark, timestamp: timestamp)
    }
    
    private static func isValidWatermark(userID: String, watermark: String, timestamp: TimeInterval) -> Bool {
        // Validate userID (should be non-empty and reasonable length)
        guard !userID.isEmpty && userID.count <= 50 else {
            return false
        }
        
        // Validate watermark components (should contain computer name and UUID)
        let watermarkComponents = watermark.components(separatedBy: ":")
        guard watermarkComponents.count >= 2 else {
            return false
        }
        
        // Validate timestamp (should be within last 10 years and not future)
        let now = Date().timeIntervalSince1970
        let tenYearsAgo = now - (10 * 365 * 24 * 60 * 60)
        guard timestamp >= tenYearsAgo && timestamp <= now + 3600 else { // Allow 1 hour future for clock skew
            return false
        }
        
        // Validate UUID format in watermark (basic check for UUID-like structure)
        let possibleUUID = watermarkComponents.last ?? ""
        let uuidPattern = "^[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}$"
        let uuidRegex = try? NSRegularExpression(pattern: uuidPattern, options: [])
        let hasValidUUID = uuidRegex?.firstMatch(in: possibleUUID, options: [], range: NSRange(location: 0, length: possibleUUID.count)) != nil
        
        return hasValidUUID
    }
    
    static func batchExtractWatermarks(from urls: [URL]) -> [(url: URL, result: (userID: String, watermark: String, timestamp: TimeInterval)?)] {
        return urls.map { url in
            (url: url, result: extractWatermarkFromPhoto(at: url))
        }
    }
    
    static func isImageFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return false
        }
        return type.conforms(to: .image)
    }
    
    static func preprocessImageForExtraction(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()
    }
}