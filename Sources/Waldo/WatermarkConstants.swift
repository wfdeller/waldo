import Foundation
import CoreGraphics
import Cocoa

/// Shared constants for watermark embedding and extraction
/// Ensures consistency between overlay generation and camera detection
struct WatermarkConstants {
    
    /// Photo Confidence Threshold
    static let PHOTO_CONFIDENCE_THRESHOLD = 0.8
    
    // MARK: - RGB Encoding Values
    
    /// Base RGB value for watermark patterns (mid-gray)
    static let RGB_BASE: Int = 128
    
    /// RGB modification strength for 1-bits (±delta from base)
    /// Higher values = more visible but more camera-detectable
    static let RGB_DELTA: Int = 25         // Balanced for camera detection
    
    /// Alpha opacity for overlay visibility (0-255)
    /// Higher values = more visible but more camera-detectable  
    static let ALPHA_OPACITY: Int = 20     // Minimally intrusive default
    
    // MARK: - Pattern Configuration
    
    /// Size of each pattern tile in pixels
    static let PATTERN_SIZE: Int = 64
    
    /// Detection threshold for extraction (should be less than RGB_DELTA)
    /// Allows tolerance for camera compression/noise
    static let DETECTION_THRESHOLD: Int = 15
    
    /// Detection tolerance for pattern matching (±pixels)
    /// Accounts for JPEG compression and camera processing
    static let DETECTION_TOLERANCE: Int = 10
    
    // MARK: - Window Positioning
    
    /// Window level adjustment for overlay positioning
    /// +1 = In front of applications (default - best for camera detection)
    /// 0 = Same level as applications  
    /// -1 = Behind applications (less visible to cameras)
    static let WINDOW_LEVEL_OFFSET: Int = 1
    
    // MARK: - Computed Values
    
    /// RGB value for 1-bits in overlay
    static var RGB_HIGH: Int { RGB_BASE + RGB_DELTA }  // 128 + 30 = 158
    
    /// RGB value for 0-bits in overlay  
    static var RGB_LOW: Int { RGB_BASE }               // 128
    
    /// Computed window level for overlay windows
    static var overlayWindowLevel: NSWindow.Level {
        return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) + WINDOW_LEVEL_OFFSET)
    }
    
    /// CGFloat versions for Core Graphics
    static var RGB_BASE_CGFloat: CGFloat { CGFloat(RGB_BASE) }
    static var RGB_DELTA_CGFloat: CGFloat { CGFloat(RGB_DELTA) }
    static var ALPHA_OPACITY_CGFloat: CGFloat { CGFloat(ALPHA_OPACITY) }
    
    // MARK: - Configuration Notes
    
    /// Camera Detection Optimization:
    /// - RGB_DELTA of 25 provides 10% signal strength for camera detection
    /// - ALPHA_OPACITY of 20 provides 8% visibility (minimally intrusive)
    /// - Primary detection relies on RGB patterns, not alpha opacity
    /// - Values can be increased for stronger watermarks or decreased for subtlety
    ///
    /// Tuning Guidelines:
    /// - Increase RGB_DELTA (25→35→45) for better camera detection
    /// - Increase ALPHA_OPACITY (20→40→60) for more visible patterns
    /// - Adjust PATTERN_SIZE (64→128) for different detection scales
    /// - Keep DETECTION_THRESHOLD < RGB_DELTA for reliable extraction
    /// - Use --opacity parameter in CLI to override default for specific needs
}