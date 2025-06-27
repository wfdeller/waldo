import CoreGraphics
import Foundation
import UniformTypeIdentifiers
import ImageIO

class PhotoProcessor {
    
    static func loadImage(from url: URL) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        return image
    }
    
    static func loadImage(from data: Data) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        return image
    }
    
    static func extractWatermarkFromPhoto(at url: URL) -> (userID: String, watermark: String, timestamp: TimeInterval)? {
        guard let image = loadImage(from: url) else {
            print("Failed to load image from: \(url)")
            return nil
        }
        
        // Try robust extraction first (for camera photos)
        if let robustResult = WatermarkEngine.extractPhotoResistantWatermark(from: image) {
            return parseWatermark(robustResult)
        }
        
        // Fall back to original steganography (for digital screenshots)
        return SteganographyEngine.extractWatermark(from: image)
    }
    
    static func extractWatermarkFromPhotoData(_ data: Data) -> (userID: String, watermark: String, timestamp: TimeInterval)? {
        guard let image = loadImage(from: data) else {
            print("Failed to load image from data")
            return nil
        }
        
        // Try robust extraction first (for camera photos)
        if let robustResult = WatermarkEngine.extractPhotoResistantWatermark(from: image) {
            return parseWatermark(robustResult)
        }
        
        // Fall back to original steganography (for digital screenshots)
        return SteganographyEngine.extractWatermark(from: image)
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