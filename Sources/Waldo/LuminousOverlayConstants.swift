import Foundation
import CoreGraphics

struct LuminousOverlayConstants {
    
    // MARK: - Luminance Pattern Constants
    static let BASE_LUMINANCE: CGFloat = 0.5
    static let LUMINANCE_DELTA: CGFloat = 0.15
    static let MIN_LUMINANCE: CGFloat = 0.1
    static let MAX_LUMINANCE: CGFloat = 0.9
    
    // MARK: - Pattern Dimensions
    static let PATTERN_SIZE: Int = 32
    static let PATTERN_TILE_SIZE: Int = 64
    static let GRADIENT_STEPS: Int = 8
    
    // MARK: - Temporal Patterns (Optional Flickering)
    static let FLICKER_FREQUENCY_HZ: Double = 2.0
    static let FLICKER_AMPLITUDE: CGFloat = 0.05
    static let ENABLE_TEMPORAL_PATTERNS: Bool = false
    
    // MARK: - Adaptive Luminance
    static let BACKGROUND_ANALYSIS_SAMPLE_SIZE: Int = 16
    static let LUMINANCE_CONTRAST_THRESHOLD: CGFloat = 0.3
    static let ADAPTIVE_ADJUSTMENT_FACTOR: CGFloat = 0.2
    
    // MARK: - Camera Optimization
    static let CAMERA_OPTIMIZED_BRIGHTNESS: CGFloat = 0.7
    static let PHONE_DETECTION_ENHANCEMENT: Bool = true
    static let LUMINANCE_ENCODING_BITS: Int = 4
    
    // MARK: - Pattern Types
    enum LuminancePattern: String, CaseIterable {
        case uniform = "uniform"
        case gradient = "gradient"
        case checkerboard = "checkerboard"
        case radial = "radial"
        case temporal = "temporal"
        
        var description: String {
            switch self {
            case .uniform:
                return "Uniform luminance across the screen"
            case .gradient:
                return "Gradient luminance patterns"
            case .checkerboard:
                return "Checkerboard luminance pattern"
            case .radial:
                return "Radial luminance pattern from center"
            case .temporal:
                return "Time-based flickering luminance pattern"
            }
        }
    }
    
    // MARK: - Color Space Conversion
    static let USE_PERCEPTUAL_LUMINANCE: Bool = true
    static let LUMINANCE_WEIGHTS_RGB: (r: CGFloat, g: CGFloat, b: CGFloat) = (0.299, 0.587, 0.114)
    
    // MARK: - Detection Enhancement
    static let LUMINANCE_ENCODING_REDUNDANCY: Int = 3
    static let ERROR_CORRECTION_LEVEL: Double = 0.25
    static let DETECTION_ZONES: Int = 4
    
    // MARK: - Positioning
    static let MARGIN_PERCENTAGE: CGFloat = 0.05
    static let CORNER_PATTERN_SIZE: CGFloat = 100
    static let CENTER_PATTERN_SIZE: CGFloat = 200
    
    // MARK: - Performance
    static let UPDATE_INTERVAL_SECONDS: Double = 1.0
    static let MAX_RENDER_TIME_MS: Double = 16.7
    static let ENABLE_HARDWARE_ACCELERATION: Bool = true
}

extension LuminousOverlayConstants {
    
    static func calculatePerceptualLuminance(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        return red * LUMINANCE_WEIGHTS_RGB.r + green * LUMINANCE_WEIGHTS_RGB.g + blue * LUMINANCE_WEIGHTS_RGB.b
    }
    
    static func adjustLuminanceForBackground(_ baseLuminance: CGFloat, backgroundLuminance: CGFloat) -> CGFloat {
        let contrast = abs(baseLuminance - backgroundLuminance)
        
        if contrast < LUMINANCE_CONTRAST_THRESHOLD {
            let adjustment = ADAPTIVE_ADJUSTMENT_FACTOR * (LUMINANCE_CONTRAST_THRESHOLD - contrast)
            if backgroundLuminance > 0.5 {
                return max(baseLuminance - adjustment, MIN_LUMINANCE)
            } else {
                return min(baseLuminance + adjustment, MAX_LUMINANCE)
            }
        }
        
        return baseLuminance
    }
    
    static func getLuminanceForPattern(_ pattern: LuminancePattern, x: Int, y: Int, time: Double = 0) -> CGFloat {
        let normalizedX = CGFloat(x) / CGFloat(PATTERN_SIZE)
        let normalizedY = CGFloat(y) / CGFloat(PATTERN_SIZE)
        
        switch pattern {
        case .uniform:
            return BASE_LUMINANCE
            
        case .gradient:
            return BASE_LUMINANCE + LUMINANCE_DELTA * normalizedX
            
        case .checkerboard:
            let checker = (x + y) % 2 == 0 ? 1.0 : -1.0
            return BASE_LUMINANCE + LUMINANCE_DELTA * CGFloat(checker)
            
        case .radial:
            let centerX = CGFloat(PATTERN_SIZE) / 2.0
            let centerY = CGFloat(PATTERN_SIZE) / 2.0
            let distance = sqrt(pow(CGFloat(x) - centerX, 2) + pow(CGFloat(y) - centerY, 2))
            let maxDistance = sqrt(pow(centerX, 2) + pow(centerY, 2))
            let normalizedDistance = distance / maxDistance
            return BASE_LUMINANCE + LUMINANCE_DELTA * normalizedDistance
            
        case .temporal:
            let flickerValue = sin(time * 2 * .pi * FLICKER_FREQUENCY_HZ) * FLICKER_AMPLITUDE
            return BASE_LUMINANCE + CGFloat(flickerValue)
        }
    }
}