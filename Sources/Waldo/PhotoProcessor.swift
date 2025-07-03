import CoreGraphics
import Foundation
import UniformTypeIdentifiers
import ImageIO

enum PhotoProcessorError: Error, CustomStringConvertible {
    case fileNotFound(URL)
    case fileEmpty(URL)
    case fileTooLarge(URL, Int64)
    case unknownFileType(URL)
    case notAnImage(URL, String)
    case imageSourceCreationFailed(URL)
    case imageCreationFailed(URL)
    case dataEmpty
    case dataTooLarge(Int)
    case imageSourceCreationFailedFromData
    case imageCreationFailedFromData
    case failedToLoadImage(String)

    var description: String {
        switch self {
        case .fileNotFound(let url):
            return "File not found at: \(url.path)"
        case .fileEmpty(let url):
            return "File is empty at: \(url.path)"
        case .fileTooLarge(let url, let size):
            return "File at \(url.path) is too large: \(size) bytes (limit: 100MB)"
        case .unknownFileType(let url):
            return "Unknown file type for extension: \(url.pathExtension)"
        case .notAnImage(let url, let type):
            return "File at \(url.path) is not a valid image type: \(type)"
        case .imageSourceCreationFailed(let url):
            return "Failed to create image source from URL: \(url.path)"
        case .imageCreationFailed(let url):
            return "Failed to create CGImage from source: \(url.path)"
        case .dataEmpty:
            return "Input data is empty."
        case .dataTooLarge(let size):
            return "Input data is too large: \(size) bytes (limit: 100MB)"
        case .imageSourceCreationFailedFromData:
            return "Failed to create image source from data."
        case .imageCreationFailedFromData:
            return "Failed to create CGImage from data source."
        case .failedToLoadImage(let reason):
            return "Failed to load image: \(reason)"
        }
    }
}

class PhotoProcessor {

    static func loadImage(from url: URL, logger: Logger = Logger()) throws -> CGImage {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.debug("Attempting to load image from: \(url.path)")

        try validateFile(at: url, logger: logger)

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw PhotoProcessorError.imageSourceCreationFailed(url)
        }

        logImageProperties(from: imageSource, logger: logger)

        guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw PhotoProcessorError.imageCreationFailed(url)
        }

        logger.timing("Image loading", duration: CFAbsoluteTimeGetCurrent() - startTime)
        logger.debug("Successfully loaded image: \(image.width)x\(image.height)")
        return image
    }

    static func loadImage(from data: Data, logger: Logger = Logger()) throws -> CGImage {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.debug("Attempting to load image from data (\(data.count) bytes)")

        guard !data.isEmpty else { throw PhotoProcessorError.dataEmpty }
        if data.count > 100_000_000 { logger.debug("Data too large: \(data.count) bytes (limit: 100MB)") }

        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw PhotoProcessorError.imageSourceCreationFailedFromData
        }

        logImageProperties(from: imageSource, logger: logger, fromData: true)

        guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw PhotoProcessorError.imageCreationFailedFromData
        }

        logger.timing("Image loading from data", duration: CFAbsoluteTimeGetCurrent() - startTime)
        logger.debug("Successfully loaded image from data: \(image.width)x\(image.height)")
        return image
    }

    static func extractWatermarkFromPhoto(at url: URL, threshold: Double = WatermarkConstants.PHOTO_CONFIDENCE_THRESHOLD, verbose: Bool = false, debug: Bool = false, enableScreenDetection: Bool = true, simpleExtraction: Bool = false) -> (userID: String, watermark: String, timestamp: TimeInterval)? {
        let logger = Logger(verbose: verbose, debug: debug)
        do {
            let image = try loadImage(from: url, logger: logger)
            let imageProperties = getImageProperties(from: url) ?? [:]
            return extractWatermark(from: image, imageProperties: imageProperties, threshold: threshold, verbose: verbose, debug: debug, enableScreenDetection: enableScreenDetection, simpleExtraction: simpleExtraction)
        } catch {
            logger.error("Failed to load image from \(url.path): \(error)")
            return nil
        }
    }

    static func extractWatermarkFromPhotoData(_ data: Data, threshold: Double = WatermarkConstants.PHOTO_CONFIDENCE_THRESHOLD, verbose: Bool = false, debug: Bool = false, enableScreenDetection: Bool = true, simpleExtraction: Bool = false) -> (userID: String, watermark: String, timestamp: TimeInterval)? {
        let logger = Logger(verbose: verbose, debug: debug)
        do {
            let image = try loadImage(from: data, logger: logger)
            let imageProperties = getImageProperties(from: data) ?? [:]
            return extractWatermark(from: image, imageProperties: imageProperties, threshold: threshold, verbose: verbose, debug: debug, enableScreenDetection: enableScreenDetection, simpleExtraction: simpleExtraction)
        } catch {
            logger.error("Failed to load image from data: \(error)")
            return nil
        }
    }

    private static func extractWatermark(from image: CGImage, imageProperties: [String: Any], threshold: Double, verbose: Bool, debug: Bool, enableScreenDetection: Bool, simpleExtraction: Bool) -> (userID: String, watermark: String, timestamp: TimeInterval)? {
        let logger = Logger(verbose: verbose, debug: debug)
        let isDesktopCapture = isDesktopCapture(properties: imageProperties)

        if verbose {
            print("Original image size: \(image.width)x\(image.height)")
            if isDesktopCapture { print("Desktop capture detected - applying enhanced preprocessing") }
        }

        var processedImage = image
        if enableScreenDetection {
            processedImage = detectAndCorrectScreen(from: image, verbose: verbose) ?? image
        }

        if isDesktopCapture {
            processedImage = preprocessImageForExtraction(processedImage, isDesktopCapture: true, debug: debug) ?? processedImage
        }

        if simpleExtraction {
            logger.debug("Using simple LSB steganography extraction only")
            return SteganographyEngine.extractWatermark(from: processedImage)
        } else {
            if let robustResult = WatermarkEngine.extractPhotoResistantWatermark(from: processedImage, threshold: threshold, verbose: verbose, debug: debug) {
                return parseWatermark(robustResult)
            }

            logger.debug("Robust extraction failed, trying steganography fallback...")
            return SteganographyEngine.extractWatermark(from: processedImage)
        }
    }

    private static func validateFile(at url: URL, logger: Logger) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            throw PhotoProcessorError.fileNotFound(url)
        }

        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? Int64 else {
            return // Not a critical error if size is unavailable
        }

        if fileSize == 0 { throw PhotoProcessorError.fileEmpty(url) }
        if fileSize > 100_000_000 { logger.debug("File too large: \(fileSize) bytes (limit: 100MB)") }

        guard let fileType = UTType(filenameExtension: url.pathExtension) else {
            throw PhotoProcessorError.unknownFileType(url)
        }

        guard fileType.conforms(to: .image) else {
            throw PhotoProcessorError.notAnImage(url, fileType.identifier)
        }
        logger.debug("File type validated: \(fileType.identifier)")
    }

    private static func logImageProperties(from imageSource: CGImageSource, logger: Logger, fromData: Bool = false) {
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            let source = fromData ? "data" : "file"
            logger.debug("Image properties from \(source): \(properties)")
            if let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int,
               let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int {
                logger.debug("Image dimensions from \(source): \(pixelWidth)x\(pixelHeight)")
            }
        }
    }

    private static func getImageProperties(from url: URL) -> [String: Any]? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
    }

    private static func getImageProperties(from data: Data) -> [String: Any]? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
    }

    private static func detectAndCorrectScreen(from image: CGImage, verbose: Bool) -> CGImage? {
        if let correctedImage = ScreenDetector.detectAndCorrectScreen(from: image, verbose: verbose) {
            if verbose { print("Screen detected and corrected, new size: \(correctedImage.width)x\(correctedImage.height)") }
            return correctedImage
        } else {
            if verbose { print("No screen detected, proceeding with original image") }
            return nil
        }
    }

    private static func parseWatermark(_ watermarkString: String) -> (userID: String, watermark: String, timestamp: TimeInterval)? {
        let components = watermarkString.components(separatedBy: ":")
        guard components.count >= 4, let timestamp = TimeInterval(components.last!) else {
            return nil
        }
        let userID = components[0]
        let watermark = components[1..<components.count-1].joined(separator: ":")
        return isValidWatermark(userID: userID, watermark: watermark, timestamp: timestamp) ? (userID, watermark, timestamp) : nil
    }

    private static func isValidWatermark(userID: String, watermark: String, timestamp: TimeInterval) -> Bool {
        guard !userID.isEmpty && userID.count <= 50 else { return false }
        let watermarkComponents = watermark.components(separatedBy: ":")
        guard watermarkComponents.count >= 2 else { return false }

        let now = Date().timeIntervalSince1970
        let tenYearsAgo = now - (10 * 365 * 24 * 60 * 60)
        guard timestamp >= tenYearsAgo && timestamp <= now + 3600 else { return false }

        let possibleUUID = watermarkComponents.last ?? ""
        let uuidPattern = "^[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}$"
        return (try? NSRegularExpression(pattern: uuidPattern).firstMatch(in: possibleUUID, range: NSRange(location: 0, length: possibleUUID.utf16.count))) != nil
    }

    static func batchExtractWatermarks(from urls: [URL]) -> [(url: URL, result: (userID: String, watermark: String, timestamp: TimeInterval)?)] {
        return urls.map { url in
            (url: url, result: extractWatermarkFromPhoto(at: url))
        }
    }

    static func isImageFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    static func preprocessImageForExtraction(_ image: CGImage, isDesktopCapture: Bool = false, debug: Bool = false) -> CGImage? {
        if isDesktopCapture {
            return preprocessDesktopCapture(image, debug: debug)
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    static func preprocessDesktopCapture(_ image: CGImage, debug: Bool = false) -> CGImage? {
        if debug { print("Debug: Applying desktop capture preprocessing") }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }

        context.interpolationQuality = .high
        context.setAlpha(1.2) // Slight contrast boost
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        guard let enhancedImage = context.makeImage() else {
            if debug { print("Debug: Failed to create enhanced image, falling back to original") }
            return image
        }

        if debug { print("Debug: Desktop capture preprocessing applied successfully") }
        return enhancedImage
    }

    static func isDesktopCapture(properties: [String: Any]) -> Bool {
        if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let userComment = exifDict[kCGImagePropertyExifUserComment as String] as? String {
            return userComment.lowercased().contains("screenshot")
        }
        return false
    }
}
