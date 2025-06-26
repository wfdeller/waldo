import Cocoa
import CoreGraphics
import Foundation

class ScreenCapture {
    
    static func captureMainDisplay() -> CGImage? {
        let displayID = CGMainDisplayID()
        return CGDisplayCreateImage(displayID)
    }
    
    static func captureAllDisplays() -> [CGImage] {
        var displayCount: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &displayCount)
        
        guard result == CGError.success else { return [] }
        
        let allocated = Int(displayCount)
        let activeDisplays = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: allocated)
        defer { activeDisplays.deallocate() }
        
        result = CGGetActiveDisplayList(displayCount, activeDisplays, &displayCount)
        guard result == CGError.success else { return [] }
        
        var images: [CGImage] = []
        for i in 0..<displayCount {
            let displayID = activeDisplays[Int(i)]
            if let image = CGDisplayCreateImage(displayID) {
                images.append(image)
            }
        }
        
        return images
    }
    
    static func saveImageAsPNG(_ image: CGImage, to url: URL) throws {
        let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
        guard let dest = destination else {
            throw WatermarkError.imageCreationFailed
        }
        
        CGImageDestinationAddImage(dest, image, nil)
        
        if !CGImageDestinationFinalize(dest) {
            throw WatermarkError.imageSaveFailed
        }
    }
    
    static func requestScreenRecordingPermission() -> Bool {
        let testImage = CGDisplayCreateImage(CGMainDisplayID())
        return testImage != nil
    }
}

enum WatermarkError: Error {
    case imageCreationFailed
    case imageSaveFailed
    case noScreenAccess
    case invalidImage
    case watermarkExtractionFailed
}