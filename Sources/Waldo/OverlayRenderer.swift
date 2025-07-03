import Foundation
import CoreGraphics
import Cocoa

protocol OverlayRenderer {
    var overlayType: OverlayType { get }
    var requiresWatermarkData: Bool { get }
    
    func createOverlayView(frame: CGRect, opacity: Int, luminous: Bool, logger: Logger) -> NSView?
    func renderOverlayImage(size: CGSize, opacity: Int, luminous: Bool, logger: Logger) -> CGImage?
    func validateParameters(opacity: Int) throws
}

extension OverlayRenderer {
    var requiresWatermarkData: Bool {
        return overlayType.supportsDataEmbedding
    }
    
    func validateParameters(opacity: Int) throws {
        guard opacity >= 1 && opacity <= 255 else {
            throw WaldoError.invalidOpacity(opacity)
        }
    }
}

protocol DataEmbeddingRenderer: OverlayRenderer {
    func createOverlayView(frame: CGRect, opacity: Int, luminous: Bool, watermarkData: String, logger: Logger) -> NSView?
    func renderOverlayImage(size: CGSize, opacity: Int, luminous: Bool, watermarkData: String, logger: Logger) -> CGImage?
}

extension DataEmbeddingRenderer {
    var requiresWatermarkData: Bool { return true }
    
    func createOverlayView(frame: CGRect, opacity: Int, luminous: Bool, logger: Logger) -> NSView? {
        let watermarkData = SystemInfo.getWatermarkDataWithHourlyTimestamp()
        return createOverlayView(frame: frame, opacity: opacity, luminous: luminous, watermarkData: watermarkData, logger: logger)
    }
    
    func renderOverlayImage(size: CGSize, opacity: Int, luminous: Bool, logger: Logger) -> CGImage? {
        let watermarkData = SystemInfo.getWatermarkDataWithHourlyTimestamp()
        return renderOverlayImage(size: size, opacity: opacity, luminous: luminous, watermarkData: watermarkData, logger: logger)
    }
}