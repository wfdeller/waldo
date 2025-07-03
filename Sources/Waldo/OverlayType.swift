import Foundation

enum OverlayType: String, CaseIterable, CustomStringConvertible {
    case qr = "qr"
    case luminous = "luminous"
    case steganography = "steganography"
    case hybrid = "hybrid"
    case beagle = "beagle"
    
    var description: String {
        switch self {
        case .qr:
            return "QR Code overlay with corner positioning"
        case .luminous:
            return "Luminous corner markers for enhanced camera detection and calibration"
        case .steganography:
            return "LSB steganography overlay (invisible pixel-level embedding)"
        case .hybrid:
            return "Hybrid overlay combining QR codes, RGB patterns, and steganography"
        case .beagle:
            return "Wireframe beagle overlay for testing purposes"
        }
    }
    
    var isVisibleOverlay: Bool {
        switch self {
        case .qr, .luminous, .hybrid, .beagle:
            return true
        case .steganography:
            return false
        }
    }
    
    var supportsDataEmbedding: Bool {
        switch self {
        case .qr, .steganography, .hybrid:
            return true
        case .luminous, .beagle:
            return false
        }
    }
    
    static func from(string: String) -> OverlayType? {
        return OverlayType(rawValue: string.lowercased().trimmingCharacters(in: .whitespaces))
    }
    
    static var defaultType: OverlayType {
        return .hybrid
    }
}

struct OverlayTypeError: Error, CustomStringConvertible {
    let invalidType: String
    
    var description: String {
        let validTypes = OverlayType.allCases.map { $0.rawValue }.joined(separator: ", ")
        return "Invalid overlay type '\(invalidType)'. Valid types: \(validTypes)"
    }
}