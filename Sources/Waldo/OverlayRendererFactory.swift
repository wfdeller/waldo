import Foundation
import CoreGraphics
import Cocoa

class OverlayRendererFactory {
    static func createRenderer(for overlayType: OverlayType) -> OverlayRenderer {
        switch overlayType {
        case .qr:
            return QROverlayRenderer()
        case .luminous:
            return LuminousOverlayRenderer()
        case .steganography:
            return SteganographyOverlayRenderer()
        case .hybrid:
            return HybridOverlayRenderer()
        case .beagle:
            return BeagleOverlayRenderer()
        }
    }
    
}