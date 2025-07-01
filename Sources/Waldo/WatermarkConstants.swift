import Foundation
import CoreGraphics
import Cocoa

/// Shared constants for watermark embedding and extraction
/// Ensures consistency between overlay generation and camera detection
struct WatermarkConstants {
    
    /// Photo Confidence Threshold (lowered for enhanced detection)
    static let PHOTO_CONFIDENCE_THRESHOLD = 0.6
    
    /// Variance threshold for adaptive thresholding (smooth vs noisy images)
    static let VARIANCE_THRESHOLD: Double = 400.0
    
    /// Threshold multipliers for adaptive detection
    static let SMOOTH_IMAGE_MULTIPLIER: Double = 0.5  // More sensitive for smooth images
    static let NOISY_IMAGE_MULTIPLIER: Double = 1.0   // Standard sensitivity for noisy images
    
    // MARK: - RGB Encoding Values
    
    /// Base RGB value for watermark patterns (mid-gray)
    static let RGB_BASE: Int = 128
    
    /// RGB modification strength for 1-bits (±delta from base)
    /// Higher values = more visible but more camera-detectable
    static let RGB_DELTA: Int = 45         // Enhanced for camera detection
    
    /// Alpha opacity for overlay visibility (0-255)
    /// Higher values = more visible but more camera-detectable  
    static let ALPHA_OPACITY: Int = 40     // Enhanced for camera detection
    
    // MARK: - Pattern Configuration
    
    /// Size of each pattern tile in pixels
    static let PATTERN_SIZE: Int = 128
    
    /// Detection threshold for extraction (should be less than RGB_DELTA)
    /// Allows tolerance for camera compression/noise
    static let DETECTION_THRESHOLD: Int = 25
    
    /// Detection tolerance for pattern matching (±pixels)
    /// Accounts for JPEG compression and camera processing
    static let DETECTION_TOLERANCE: Int = 20
    
    // MARK: - QR Code Detection
    
    /// Fixed threshold for binary QR detection (fallback)
    static let QR_BINARY_THRESHOLD: Int = 127
    
    /// Sample radius for adaptive threshold calculation 
    static let QR_THRESHOLD_SAMPLE_RADIUS: Int = 5
    
    /// Finder pattern validation tolerance (0.0-1.0)
    /// 0.8 = allow 20% pixel mismatches for noise tolerance
    static let QR_FINDER_PATTERN_TOLERANCE: Double = 0.8
    
    // MARK: - Version 2 QR Code Constants
    
    /// Version 2 QR code module size (37x37)
    static let QR_VERSION2_SIZE: Int = 37
    
    /// Pixels per QR module for Version 2 overlay codes
    static let QR_VERSION2_PIXELS_PER_MODULE: Int = 5
    
    /// Total pixel size for Version 2 QR codes (37 * 5 = 185)
    static let QR_VERSION2_PIXEL_SIZE: Int = QR_VERSION2_SIZE * QR_VERSION2_PIXELS_PER_MODULE
    
    /// Enhanced margin for Version 2 QR codes
    static let QR_VERSION2_MARGIN: Int = 15
    
    /// Enhanced menu bar offset for Version 2 QR codes
    static let QR_VERSION2_MENU_BAR_OFFSET: Int = 50
    
    // MARK: - Window Positioning
    
    /// Window level adjustment for overlay positioning
    /// +1 = In front of applications (default - best for camera detection)
    /// 0 = Same level as applications  
    /// -1 = Behind applications (less visible to cameras)
    static let WINDOW_LEVEL_OFFSET: Int = 1
    
    // MARK: - Computed Values
    
    /// RGB value for 1-bits in overlay
    static var RGB_HIGH: Int { RGB_BASE + RGB_DELTA }  // 128 + 45 = 173
    
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
    /// - RGB_DELTA of 45 provides 18% signal strength for enhanced camera detection
    /// - ALPHA_OPACITY of 40 provides 16% visibility (enhanced for detection)
    /// - Primary detection relies on RGB patterns, not alpha opacity
    /// - Values can be increased for stronger watermarks or decreased for subtlety
    ///
    /// Tuning Guidelines:
    /// - Increase RGB_DELTA (25→35→45) for better camera detection
    /// - Increase ALPHA_OPACITY (40→60→80) for more visible patterns
    /// - Adjust PATTERN_SIZE (64→128) for different detection scales
    /// - Keep DETECTION_THRESHOLD < RGB_DELTA for reliable extraction
    /// - Use --opacity parameter in CLI to override default for specific needs
}