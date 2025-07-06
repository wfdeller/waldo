using System;

namespace Waldo.Core
{
    /// <summary>
    /// Shared constants for watermark embedding and extraction
    /// Ensures consistency between overlay generation and camera detection
    /// </summary>
    public static class WatermarkConstants
    {
        /// <summary>
        /// Photo Confidence Threshold (lowered for enhanced detection)
        /// </summary>
        public const double PHOTO_CONFIDENCE_THRESHOLD = 0.3;
        
        /// <summary>
        /// Variance threshold for adaptive thresholding (smooth vs noisy images)
        /// </summary>
        public const double VARIANCE_THRESHOLD = 400.0;
        
        /// <summary>
        /// Threshold multipliers for adaptive detection
        /// </summary>
        public const double SMOOTH_IMAGE_MULTIPLIER = 0.3;  // More sensitive for smooth images
        public const double NOISY_IMAGE_MULTIPLIER = 0.7;   // Enhanced sensitivity for noisy images
        
        // MARK: - RGB Encoding Values
        
        /// <summary>
        /// Base RGB value for watermark patterns (mid-gray)
        /// </summary>
        public const int RGB_BASE = 128;
        
        /// <summary>
        /// RGB modification strength for 1-bits (±delta from base)
        /// Higher values = more visible but more camera-detectable
        /// </summary>
        public const int RGB_DELTA = 65;         // Enhanced for desktop capture detection
        
        /// <summary>
        /// Alpha opacity for overlay visibility (0-255)
        /// Higher values = more visible but more camera-detectable
        /// </summary>
        public const int ALPHA_OPACITY = 40;     // Enhanced for camera detection
        
        // MARK: - Pattern Configuration
        
        /// <summary>
        /// Size of each pattern tile in pixels
        /// </summary>
        public const int PATTERN_SIZE = 128;
        
        /// <summary>
        /// Detection threshold for extraction (should be less than RGB_DELTA)
        /// Allows tolerance for camera compression/noise
        /// </summary>
        public const int DETECTION_THRESHOLD = 35;
        
        /// <summary>
        /// Detection tolerance for pattern matching (±pixels)
        /// Accounts for JPEG compression and camera processing
        /// </summary>
        public const int DETECTION_TOLERANCE = 20;
        
        // MARK: - QR Code Detection
        
        /// <summary>
        /// Fixed threshold for binary QR detection (fallback)
        /// </summary>
        public const int QR_BINARY_THRESHOLD = 127;
        
        /// <summary>
        /// Sample radius for adaptive threshold calculation
        /// </summary>
        public const int QR_THRESHOLD_SAMPLE_RADIUS = 5;
        
        /// <summary>
        /// Finder pattern validation tolerance (0.0-1.0)
        /// 0.8 = allow 20% pixel mismatches for noise tolerance
        /// </summary>
        public const double QR_FINDER_PATTERN_TOLERANCE = 0.8;
        
        // MARK: - Version 2 QR Code Constants
        
        /// <summary>
        /// Version 2 QR code module size (37x37)
        /// </summary>
        public const int QR_VERSION2_SIZE = 37;
        
        /// <summary>
        /// Pixels per QR module for Version 2 overlay codes
        /// </summary>
        public const int QR_VERSION2_PIXELS_PER_MODULE = 5;
        
        /// <summary>
        /// Total pixel size for Version 2 QR codes (37 * 5 = 185)
        /// </summary>
        public const int QR_VERSION2_PIXEL_SIZE = QR_VERSION2_SIZE * QR_VERSION2_PIXELS_PER_MODULE;
        
        /// <summary>
        /// Enhanced margin for Version 2 QR codes
        /// </summary>
        public const int QR_VERSION2_MARGIN = 15;
        
        /// <summary>
        /// Enhanced menu bar offset for Version 2 QR codes
        /// </summary>
        public const int QR_VERSION2_MENU_BAR_OFFSET = 50;
        
        // MARK: - Window Positioning
        
        /// <summary>
        /// Window level adjustment for overlay positioning
        /// +1 = In front of applications (default - best for camera detection)
        /// 0 = Same level as applications
        /// -1 = Behind applications (less visible to cameras)
        /// </summary>
        public const int WINDOW_LEVEL_OFFSET = 1;
        
        // MARK: - Computed Values
        
        /// <summary>
        /// RGB value for 1-bits in overlay
        /// </summary>
        public static int RGB_HIGH => RGB_BASE + RGB_DELTA;  // 128 + 65 = 193
        
        /// <summary>
        /// RGB value for 0-bits in overlay
        /// </summary>
        public static int RGB_LOW => RGB_BASE;               // 128
        
        /// <summary>
        /// Float versions for drawing operations
        /// </summary>
        public static float RGB_BASE_FLOAT => (float)RGB_BASE;
        public static float RGB_DELTA_FLOAT => (float)RGB_DELTA;
        public static float ALPHA_OPACITY_FLOAT => (float)ALPHA_OPACITY;
        
        // MARK: - Configuration Notes
        
        /// <summary>
        /// Desktop Capture Detection Optimization:
        /// - RGB_DELTA of 65 provides 25.5% signal strength for enhanced desktop capture detection (65/255)
        /// - ALPHA_OPACITY of 40 provides 15.7% visibility (enhanced for detection) (40/255)
        /// - PHOTO_CONFIDENCE_THRESHOLD lowered to 0.3 for more sensitive detection
        /// - Adaptive thresholds made more sensitive for both smooth and noisy images
        /// - Primary detection relies on RGB patterns, not alpha opacity
        ///
        /// Tuning Guidelines:
        /// - Increased RGB_DELTA (45→65) for better desktop capture detection
        /// - Lowered PHOTO_CONFIDENCE_THRESHOLD (0.6→0.3) for more sensitive detection
        /// - Enhanced DETECTION_THRESHOLD (25→35) to match increased RGB_DELTA
        /// - More sensitive adaptive multipliers for compressed desktop captures
        /// - Keep DETECTION_THRESHOLD < RGB_DELTA for reliable extraction
        /// - Use --opacity parameter in CLI to override default for specific needs
        /// </summary>
        public static class Documentation
        {
            public const string OPTIMIZATION_NOTES = @"
Desktop Capture Detection Optimization:
- RGB_DELTA of 65 provides 25.5% signal strength for enhanced desktop capture detection (65/255)
- ALPHA_OPACITY of 40 provides 15.7% visibility (enhanced for detection) (40/255)
- PHOTO_CONFIDENCE_THRESHOLD lowered to 0.3 for more sensitive detection
- Adaptive thresholds made more sensitive for both smooth and noisy images
- Primary detection relies on RGB patterns, not alpha opacity

Tuning Guidelines:
- Increased RGB_DELTA (45→65) for better desktop capture detection
- Lowered PHOTO_CONFIDENCE_THRESHOLD (0.6→0.3) for more sensitive detection
- Enhanced DETECTION_THRESHOLD (25→35) to match increased RGB_DELTA
- More sensitive adaptive multipliers for compressed desktop captures
- Keep DETECTION_THRESHOLD < RGB_DELTA for reliable extraction
- Use --opacity parameter in CLI to override default for specific needs";
        }
    }
}