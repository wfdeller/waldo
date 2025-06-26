import CoreGraphics
import Foundation

class SteganographyEngine {
    
    static func embedWatermark(in image: CGImage, watermark: String, userID: String) -> CGImage? {
        let fullWatermark = "\(userID):\(watermark):\(Date().timeIntervalSince1970)"
        let watermarkData = Data(fullWatermark.utf8)
        
        guard let pixelData = extractPixelData(from: image) else { return nil }
        
        var modifiedPixelData = pixelData
        let totalPixels = image.width * image.height
        let watermarkBits = watermarkData.flatMap { byte in
            (0..<8).map { (byte >> $0) & 1 }
        }
        
        let lengthBits = withUnsafeBytes(of: UInt32(watermarkBits.count).bigEndian) { bytes in
            bytes.flatMap { byte in
                (0..<8).map { (byte >> $0) & 1 }
            }
        }
        
        let allBits = lengthBits + watermarkBits
        
        guard allBits.count <= totalPixels * 3 else { return nil }
        
        for (index, bit) in allBits.enumerated() {
            let pixelIndex = (index / 3) * 4 + (index % 3)
            if pixelIndex < modifiedPixelData.count {
                modifiedPixelData[pixelIndex] = (modifiedPixelData[pixelIndex] & 0xFE) | UInt8(bit)
            }
        }
        
        return createImage(from: modifiedPixelData, width: image.width, height: image.height)
    }
    
    static func extractWatermark(from image: CGImage) -> (userID: String, watermark: String, timestamp: TimeInterval)? {
        guard let pixelData = extractPixelData(from: image) else { return nil }
        
        let lengthBits = (0..<32).compactMap { bitIndex -> UInt8? in
            let pixelIndex = (bitIndex / 3) * 4 + (bitIndex % 3)
            guard pixelIndex < pixelData.count else { return nil }
            return pixelData[pixelIndex] & 1
        }
        
        let lengthBytes = stride(from: 0, to: lengthBits.count, by: 8).map { startIndex in
            lengthBits[startIndex..<min(startIndex + 8, lengthBits.count)]
                .enumerated()
                .reduce(UInt8(0)) { result, element in
                    result | (element.element << element.offset)
                }
        }
        
        let watermarkLength = Int(Data(lengthBytes).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
        
        guard watermarkLength > 0 && watermarkLength <= 10000 else { return nil }
        
        let watermarkBits = (32..<32 + watermarkLength).compactMap { bitIndex -> UInt8? in
            let pixelIndex = (bitIndex / 3) * 4 + (bitIndex % 3)
            guard pixelIndex < pixelData.count else { return nil }
            return pixelData[pixelIndex] & 1
        }
        
        let watermarkBytes = stride(from: 0, to: watermarkBits.count, by: 8).map { startIndex in
            watermarkBits[startIndex..<min(startIndex + 8, watermarkBits.count)]
                .enumerated()
                .reduce(UInt8(0)) { result, element in
                    result | (element.element << element.offset)
                }
        }
        
        guard let watermarkString = String(data: Data(watermarkBytes), encoding: .utf8) else {
            return nil
        }
        
        let components = watermarkString.components(separatedBy: ":")
        guard components.count >= 3,
              let timestamp = TimeInterval(components.last!) else {
            return nil
        }
        
        let userID = components[0]
        let watermark = components[1..<components.count-1].joined(separator: ":")
        
        return (userID: userID, watermark: watermark, timestamp: timestamp)
    }
    
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
}