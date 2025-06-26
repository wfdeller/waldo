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
        
        return SteganographyEngine.extractWatermark(from: image)
    }
    
    static func extractWatermarkFromPhotoData(_ data: Data) -> (userID: String, watermark: String, timestamp: TimeInterval)? {
        guard let image = loadImage(from: data) else {
            print("Failed to load image from data")
            return nil
        }
        
        return SteganographyEngine.extractWatermark(from: image)
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