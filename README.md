# Waldo - Watermark System

A macOS steganographic identification system with camera-detectable transparent overlays.

## Features

### Modular Overlay Types

-   **QR Code Overlays**: Corner-positioned QR codes with high error correction
-   **Luminous Overlays**: Brightness-based corner markers for enhanced camera detection and calibration
-   **Steganography Overlays**: Invisible LSB embedding in pixel data
-   **Hybrid Overlays**: Combines QR codes, RGB patterns, and steganography
-   **Beagle Overlays**: Wireframe patterns for testing and development
-   **Luminous Enhancement**: Add luminous corner markers to any overlay type with `--luminous` flag

### Camera Detection Optimization

-   **Luminance-Based Patterns**: Attempts to use brightness variations for better phone camera detection
-   **Adaptive Brightness**: Attempts to adjust luminance based on background content
-   **Blue Channel Modulation**: Attempts to embed QR data in blue channel for camera sensitivity
-   **Corner Positioning**: Attempts to place detection markers in screen corners

### Desktop Watermarking

-   **Transparent Overlays**: Nearly invisible watermarks on all displays in real-time
-   **System Detection**: Auto-detects username, machine UUID, and computer name
-   **Hourly Refresh**: Watermarks update automatically with current timestamp
-   **Multi-Display Support**: Works across multiple monitors

### Steganography

-   **Watermarking Engine**: DCT, redundant, and micro QR pattern embedding
-   **Camera Photo Extraction**: Identify watermarks from phone photos of screens
-   **Compression Resistant**: Survives JPEG compression, scaling, and camera noise
-   **Multiple Detection Methods**: Overlay extraction, spread spectrum, and LSB steganography
-   **Desktop Capture Detection**: Detects and enhances screenshot images
-   **Parameter Tuning**: Optimized thresholds and signal strength for desktop captures

### Testing & Validation

-   **End-to-End Testing**: Complete overlay save and extract validation
-   **Round-trip Verification**: Test watermark embedding and extraction cycles
-   **Performance Benchmarking**: Debug timing and infinite loop protection
-   **Multiple Extraction Methods**: ROI processing and simple LSB extraction
-   **Desktop Capture Testing**: Testing with multiple opacity levels
-   **Parameter Testing**: Progressive threshold testing (0.1, 0.2, 0.3)
-   **Screenshot Simulation**: Testing of desktop capture scenarios

## Quick Start

### 1. Build and Test

```bash
# Build the application
swift build
# or
make build

# Run test suite to validate functionality
./test_roundtrip.sh
```

### 2. Start Camera-Resistant Overlay

```bash
# Start camera-detectable overlay watermarking (default hybrid type)
./.build/debug/waldo overlay start --daemon

# Start with specific overlay type for better camera detection
./.build/debug/waldo overlay start luminous --daemon

# Start with luminous enhancement for better camera detection
./.build/debug/waldo overlay start qr --luminous --daemon

# Check overlay status
./.build/debug/waldo overlay status --verbose

# Stop overlay
./.build/debug/waldo overlay stop
```

### 3. Test Camera Detection

```bash
# Take a photo of your screen with your phone/camera
# Extract watermark from the camera photo
./.build/debug/waldo extract ~/path/to/camera/photo.jpg --threshold 0.3 --verbose

# For desktop captures/screenshots
./.build/debug/waldo extract ~/path/to/screenshot.png --threshold 0.2 --debug
```

## Commands

### Overlay Management

```bash
# Start overlay with specific type (new feature)
waldo overlay start [overlay-type] [--luminous] [--daemon] [--opacity 40] [--verbose] [--debug]

# Available overlay types:
waldo overlay start qr                    # QR codes only
waldo overlay start luminous              # Luminous brightness patterns (markers only)
waldo overlay start steganography         # LSB steganography only
waldo overlay start hybrid               # QR + RGB + steganography (default)
waldo overlay start beagle               # Wireframe beagle (testing)

# Luminous enhancement flag (adds corner markers for better detection):
waldo overlay start qr --luminous         # QR codes with luminous markers
waldo overlay start steganography --luminous # Steganography with luminous markers
waldo overlay start hybrid --luminous     # Hybrid overlay with luminous markers


# Default overlay type (hybrid) when no type specified
waldo overlay start [--luminous] [--daemon] [--opacity 40] [--verbose] [--debug]

# Stop overlay watermarking
waldo overlay stop [--verbose] [--debug]

# Check overlay status and system info
waldo overlay status [--verbose] [--debug]

# Save overlay as PNG for testing
waldo overlay save-overlay test.png [--width 800] [--height 600] [--opacity 60] [--verbose] [--debug]

# Debug screen information
waldo overlay debug-screen
```

### Watermark Extraction

```bash
# Extract watermark from camera photo of screen (full pipeline)
waldo extract "/path/to/camera/photo.jpg" --verbose

# Extract using simple LSB steganography (fast, for testing)
waldo extract "test.png" --simple-extraction --debug

# Extract with desktop parameters
waldo extract "screenshot.png" --threshold 0.3 --debug

# Extract with low threshold for difficult images
waldo extract "photo.jpg" --threshold 0.2 --no-screen-detection

# Extract with debug information
waldo extract "photo.jpg" --verbose --debug
```

### Makefile Commands

```bash
# Build the project
make build

# Run tests
make test

# Install executable
make install

# Clean build artifacts
make clean

# Show all available commands
make help
```

## End-to-End Testing

### Round-Trip Validation

Test Waldo's functionality through end-to-end round-trip testing:

#### 1. Basic Round-Trip Test

```bash
# Create a test overlay with embedded watermark
waldo overlay save-overlay test_basic.png --width 400 --height 300 --opacity 100

# Extract the watermark to verify it works
waldo extract test_basic.png --simple-extraction

# Expected output:
# Watermark detected!
# Username: your_username
# Computer-name: Your-Computer-Name
# Machine-uuid: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
# Timestamp: Dec 25, 2024 at 2:30:00 PM
```

#### 2. Testing Suite

```bash
# Test different image sizes
waldo overlay save-overlay small.png --width 300 --height 200 --opacity 80
waldo overlay save-overlay medium.png --width 800 --height 600 --opacity 60
waldo overlay save-overlay large.png --width 1600 --height 1200 --opacity 100

# Validate each overlay
waldo extract small.png --simple-extraction
waldo extract medium.png --simple-extraction
waldo extract large.png --simple-extraction
```

#### 3. Debug Testing

```bash
# Create overlay with full debug information
waldo overlay save-overlay debug_test.png --width 600 --height 400 --debug

# Extract with detailed debug output
waldo extract debug_test.png --simple-extraction --debug

# This shows:
# - File I/O operations and timing
# - LSB steganography embedding/extraction process
# - Performance metrics
# - Error detection and handling
```

#### 4. Performance Benchmarking

```bash
# Test creation performance
echo "Creating overlay..."
time waldo overlay save-overlay benchmark.png --width 1920 --height 1080

# Test extraction performance
echo "Extracting watermark..."
time waldo extract benchmark.png --simple-extraction

# Compare extraction methods
echo "=== Simple Extraction ==="
time waldo extract benchmark.png --simple-extraction
echo "=== Full Pipeline ==="
time waldo extract benchmark.png --no-screen-detection
```

#### 5. Threshold Testing

```bash
# Create test overlay
waldo overlay save-overlay threshold_test.png --width 400 --height 300

# Test different confidence thresholds
waldo extract threshold_test.png --simple-extraction --threshold 0.1
waldo extract threshold_test.png --simple-extraction --threshold 0.5
waldo extract threshold_test.png --simple-extraction --threshold 0.9
```

#### 6. Test Script

The project includes a test script `test_roundtrip.sh` that validates Waldo functionality:

```bash
# Run the test suite
./test_roundtrip.sh

# Run with verbose output
./test_roundtrip.sh --verbose

# Run with debug information
./test_roundtrip.sh --debug

# Keep test files for inspection
./test_roundtrip.sh --keep-files

# Run only desktop capture tests
./test_roundtrip.sh --desktop-only

# Debug desktop capture issues
./test_roundtrip.sh --desktop-only --debug --verbose

# Show help
./test_roundtrip.sh --help
```

**Test Script Features:**

-   ✅ **8 Core Round-trip Tests**: Different image sizes and opacities
-   ✅ **Performance Testing**: Creation and extraction timing
-   ✅ **Threshold Testing**: Multiple confidence threshold validation (0.1-0.9)
-   ✅ **Desktop Capture Testing**: Real overlay capture and extraction testing
-   ✅ **Desktop Capture Tests**: Multiple opacity levels (60, 80, 100, 120, 150)
-   ✅ **Progressive Extraction**: Tests multiple extraction methods per image
-   ✅ **Edge Case Testing**: Very small images, extreme opacities
-   ✅ **Parameter Testing**: Desktop-optimized thresholds and preprocessing
-   ✅ **Colored Output**: Clear pass/fail indicators
-   ✅ **Error Debugging**: Optional verbose and debug modes
-   ✅ **Cleanup Management**: Automatic or optional file preservation

**Expected Output:**

```
=== Waldo Round-trip Validation Test Suite ===
Binary: ./.build/arm64-apple-macosx/debug/waldo
Temp directory: ./test_temp

=== Core Round-trip Tests ===
Running Small overlay (300x200)... ✅ Small overlay (300x200) PASSED
Running Medium overlay (800x600)... ✅ Medium overlay (800x600) PASSED
Running Large overlay (1200x900)... ✅ Large overlay (1200x900) PASSED
Running High opacity overlay... ✅ High opacity overlay PASSED
Running Low opacity overlay... ✅ Low opacity overlay PASSED
Running Square overlay... ✅ Square overlay PASSED
Running Wide overlay (16:9)... ✅ Wide overlay (16:9) PASSED
Running Tall overlay (9:16)... ✅ Tall overlay (9:16) PASSED

=== Performance Testing ===
Testing creation performance...
✅ Overlay creation: 23ms
Testing extraction performance...
✅ Watermark extraction: 8ms

=== Threshold Testing ===
Testing threshold 0.1... ✅ PASSED
Testing threshold 0.3... ✅ PASSED
Testing threshold 0.5... ✅ PASSED
Testing threshold 0.7... ✅ PASSED
Testing threshold 0.9... ✅ PASSED
Threshold tests: 5/5 passed

=== Desktop Overlay Testing ===
Starting desktop overlay... ✅ Overlay started successfully
Testing desktop capture... ✅ Desktop captured successfully
Testing extraction from desktop capture... ✅ Desktop extraction PASSED (with enhanced parameters)
Stopping desktop overlay... ✅ Overlay stopped

=== Desktop Capture Testing ===
Testing desktop capture with opacity 60... ✅ PASSED (opacity 60, method: enhanced)
Testing desktop capture with opacity 80... ✅ PASSED (opacity 80, method: enhanced)
Testing desktop capture with opacity 100... ✅ PASSED (opacity 100, method: enhanced)
Testing desktop capture with opacity 120... ✅ PASSED (opacity 120, method: low-threshold)
Testing desktop capture with opacity 150... ✅ PASSED (opacity 150, method: enhanced)
Desktop capture tests: 5/5 passed

=== Edge Case Testing ===
Testing very small image (100x100)... ✅ PASSED
Testing very high opacity (200)... ✅ PASSED
Testing low opacity (10)... ✅ PASSED

=== Test Results Summary ===
✅ All core tests passed: 8/8
🎉 Waldo round-trip validation: SUCCESS

Next steps:
  • Test with real camera photos: waldo overlay start && take photo && waldo extract photo.jpg
  • Test desktop capture: waldo overlay start --opacity 100 && waldo overlay save-desktop desktop.png && waldo extract desktop.png --threshold 0.3
  • Test screenshot extraction: waldo extract screenshot.png --threshold 0.2 --debug
  • Run performance benchmarks: time waldo overlay save-overlay test.png && time waldo extract test.png --simple-extraction
  • Debug desktop capture: waldo extract desktop.png --threshold 0.1 --debug --verbose
```

### Camera Photo Testing

#### 1. Real Camera Test

```bash
# Start luminous overlay for better camera detection
waldo overlay start luminous --opacity 60

# Or combine overlay types for maximum robustness
waldo overlay start qr,luminous --opacity 80

# Take a photo of your screen with a phone/camera
# Save the photo to your computer

# Extract watermark from camera photo
waldo extract ~/Downloads/camera_photo.jpg --verbose

# Clean up
waldo overlay stop
```

#### 2. Expected Results

**Successful Extraction Output:**

```
Waldo v2.1.0
Using confidence threshold: 0.6
Original image size: 3024x4032
Screen detected and corrected, new size: 1800x1013
Watermark detected!
Username: alice
Computer-name: Alices-MacBook-Pro
Machine-uuid: A1B2C3D4-E5F6-7890-ABCD-EF1234567890
Timestamp: Dec 25, 2024 at 2:30:00 PM
```

### Troubleshooting Tests

#### 1. Debug Screen Detection Issues

```bash
# Check screen configuration
waldo overlay debug-screen

# Test screen detection specifically
waldo extract photo.jpg --verbose --debug
# Look for screen detection timing and failure analysis
```

#### 2. Performance Issues

```bash
# Use simple extraction to bypass complex processing
waldo extract photo.jpg --simple-extraction --debug

# Check for infinite loop protection
# Look for "Edge tracking completed: X iterations" in output
```

#### 3. File Format Issues

```bash
# Test with debug to see file validation
waldo extract suspicious_file.jpg --debug
# Shows file size, format validation, and image properties
```

#### 4. Test Script Issues

```bash
# If test script fails, run with debug to see details
./test_roundtrip.sh --debug

# Keep test files for manual inspection
./test_roundtrip.sh --keep-files

# Check if waldo binary exists
ls -la ./.build/arm64-apple-macosx/debug/waldo

# Rebuild if binary is missing
swift build
```

## How It Works

### Modular Overlay System

1. **Overlay Type Selection**: Choose from QR, luminous, steganography, hybrid, or beagle overlays
2. **Luminous Patterns**: Attempts to use brightness variations for enhanced camera detection
3. **QR Code Positioning**: Attempts to place QR codes in screen corners with blue channel modulation
4. **LSB Steganography**: Embeds watermark data in the least significant bits of image pixels
5. **Composite Rendering**: Attempts to combine multiple overlay types for increased robustness
6. **Adaptive Detection**: Attempts to use luminance analysis and QR pattern matching
7. **Hourly Refresh**: Updates watermark data every hour for temporal tracking

### Extraction Process

1. **File Validation**: File format and size checking
2. **Desktop Capture Detection**: Identification of screenshots via EXIF data
3. **Preprocessing**: Desktop-specific image enhancement and contrast boosting
4. **Screen Detection**: Optional perspective correction for camera photos
5. **Multi-Method Extraction**:
    - **Luminous Detection**: Attempts to analyze brightness patterns in corner regions
    - **ROI Pipeline**: Multi-region enhancement for QR code detection
    - **Simple LSB Extraction**: Fast steganographic decoding for digital screenshots
6. **Progressive Parameter Testing**: Multiple threshold levels for difficult extractions
7. **Error Correction**: Reconstructs watermark data with validation
8. **Performance Protection**: Timeout and iteration limits prevent infinite loops

### Desktop Capture Optimization

1. **EXIF Analysis**: Detects screenshots by analyzing metadata (`UserComment: Screenshot`)
2. **Signal Strength**: 25.5% RGB delta for stronger patterns (65/255)
3. **Adaptive Thresholds**: Lower confidence thresholds (0.3 vs 0.6) for sensitive detection
4. **Preprocessing**: High-quality interpolation and contrast enhancement
5. **Progressive Extraction**: Multiple extraction methods with fallback strategies

### Watermark Format

```
username:computer-name:machine-uuid:timestamp
```

Example: `alice:Alices-MacBook-Pro:A1B2C3D4-E5F6:1703875200`

## Overlay Types

### QR Code Overlays (`qr`)

Attempts to place QR codes in screen corners with error correction:
- Corner positioning for camera detection
- Blue channel modulation for camera sensitivity
- High error correction for photo capture robustness
- Embeds username, machine name, UUID, and timestamp

```bash
waldo overlay start qr --opacity 80
```

### Luminous Overlays (`luminous`)

Attempts to use brightness variations for enhanced camera detection:
- Brightness-based patterns across the screen
- Adaptive luminance based on background content
- Corner luminance markers for detection
- Perceptual luminance calculations

```bash
waldo overlay start luminous --opacity 60
```

### Steganography Overlays (`steganography`)

Invisible LSB embedding in pixel data:
- Least Significant Bit steganography
- Invisible to human vision
- Embeds watermark data in pixel channels
- Best for digital screenshots

```bash
waldo overlay start steganography --opacity 40
```

### Hybrid Overlays (`hybrid`, default)

Combines QR codes, RGB patterns, and steganography:
- Maintains backward compatibility
- Uses existing WatermarkOverlayView implementation
- Multiple redundant embedding methods
- Balanced approach for all scenarios

```bash
waldo overlay start hybrid --opacity 50
waldo overlay start  # defaults to hybrid
```

### Beagle Overlays (`beagle`)

Wireframe patterns for testing and development:
- Simple wireframe beagle drawings
- Includes username text
- Visible overlay for testing
- No watermark data embedding

```bash
waldo overlay start beagle --opacity 100
```

### Composite Overlays

Multiple overlay types can be combined:
```bash
waldo overlay start qr,luminous --opacity 70        # QR + luminous
waldo overlay start qr,steganography --opacity 60   # QR + steganography
waldo overlay start luminous,steganography          # Luminous + steganography
```

## Configuration

### macOS Permissions

-   **Screen Recording Permission**: Required for overlay windows
-   Automatically requests permission on first run

### Command Line Options

#### Save Overlay Options

-   `--width`: Image width (default: 1920)
-   `--height`: Image height (default: 1080)
-   `--opacity`: Overlay opacity 1-255 (default: 40)
-   `--debug`: Show debug information

#### Extract Options

-   `--threshold`: Confidence threshold 0.0-1.0 (default: 0.3, optimized for desktop captures)
-   `--verbose`: Show detailed processing information
-   `--debug`: Show debug information for failures and desktop capture detection
-   `--no-screen-detection`: Skip screen detection and perspective correction
-   `--simple-extraction`: Use fast LSB steganography only (skip ROI processing)

#### Extraction Parameters

For best results with different image types:

-   **Desktop Captures/Screenshots**: `--threshold 0.2` or `0.3`
-   **Camera Photos**: `--threshold 0.3` or `0.4` 
-   **Difficult/Compressed Images**: `--threshold 0.1` or `0.2`
-   **High Quality Images**: `--threshold 0.5` or higher

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Overlay System │    │  Save Command   │    │ Extract Command │
│                 │    │                 │    │                 │
│ NSWindow        │    │ LSB Embedding   │    │ ROI Processing  │
│ Transparency    │───▶│ PNG Export      │───▶│ LSB Extraction  │
│ Multi-Display   │    │ Debug Logging   │    │ Screen Detection│
│ Auto-Refresh    │    │ Steganography   │    │ Pattern Matching│
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Use Cases

### 📱 Camera Photo Forensics

-   **Identify photographed screens**: Trace camera photos back to specific users and machines
-   **Corporate leak prevention**: Detect unauthorized screen photography
-   **Legal evidence**: Provide proof of screen photo origins in legal proceedings
-   **Intellectual property protection**: Track photos of sensitive displays

### 🔒 Corporate Desktop Security

-   **Employee monitoring**: Track desktop usage and screen access
-   **Leak detection**: Identify sources of unauthorized screenshots or photos
-   **Audit trails**: Maintain detailed logs of desktop watermarking activity
-   **Insider threat detection**: Monitor for suspicious photography behavior

### 🛡️ Content Protection

-   **Sensitive data tracking**: Watermark confidential information displays
-   **Document leakage prevention**: Trace unauthorized screen captures
-   **Compliance monitoring**: Ensure regulatory compliance for data protection
-   **Forensic investigation**: Reconstruct timeline of screen access events

### 🧪 Testing & Development

-   **Round-trip validation**: Verify watermark embedding and extraction
-   **Performance benchmarking**: Test system performance and reliability
-   **Format compatibility**: Validate different image sizes and formats
-   **Debug troubleshooting**: Comprehensive diagnostic information

## Security Considerations

### 🔐 Steganographic Security

-   **Nearly Invisible**: Camera-detectable but imperceptible to human vision
-   **Robust Against Attacks**: Survives camera capture, compression, and scaling
-   **Multiple Embedding Layers**: Redundant techniques prevent single-point failure
-   **LSB Steganography**: Reliable bit-level embedding for digital screenshots

### 🏢 Enterprise Security

-   **Local Processing**: All watermark processing done locally
-   **No Network Dependencies**: Works completely offline
-   **Minimal Performance Impact**: Lightweight overlay rendering
-   **Cross-Process Detection**: Status checking works across multiple processes
-   **Timeout Protection**: Prevents infinite loops and system hangs

## Development

### Prerequisites

-   macOS 13.0+
-   Swift 5.9+
-   Xcode Command Line Tools

### Building

```bash
# Swift application
swift build

# Using Make
make build

# Install system-wide
make install
```

### Testing

#### Test Suite

**Automated Testing (Recommended):**

```bash
# Build first, then run test suite
swift build
./test_roundtrip.sh

# For detailed output
./test_roundtrip.sh --verbose --debug
```

**Manual Testing:**

```bash
# Quick validation (30 seconds)
waldo overlay save-overlay quick.png --width 400 --height 300
waldo extract quick.png --simple-extraction

# Full validation (2 minutes)
waldo overlay save-overlay full.png --width 1024 --height 768 --debug
waldo extract full.png --simple-extraction --verbose --debug

# Performance benchmark
time waldo overlay save-overlay perf.png --width 1920 --height 1080
time waldo extract perf.png --simple-extraction
```

#### Camera-Resistant Watermarking Test

```bash
# Test different overlay types for camera detection
waldo overlay start luminous --opacity 60           # Brightness-based
waldo overlay start qr --opacity 80                 # QR codes only
waldo overlay start qr,luminous --opacity 100       # Combined approach

# Take photo of screen with phone/camera
# Extract watermark from camera photo
waldo extract ~/path/to/camera_photo.jpg --verbose

# Expected output:
# Watermark detected!
# Username: your_username
# Computer: Your-Computer-Name

# Clean up
waldo overlay stop
```

#### Edge Case Testing

```bash
# Test with various file formats
waldo extract test.jpg --simple-extraction
waldo extract test.png --simple-extraction
waldo extract test.heic --simple-extraction

# Test error conditions
waldo extract nonexistent.png --debug
waldo extract corrupted.jpg --debug
waldo extract empty_file.png --debug
```

## Key Innovation

**Waldo represents a breakthrough in digital forensics** - the first system capable of reliably identifying the source of camera photos taken of computer screens. This bridges the gap between digital steganography and physical evidence, enabling traceability for screen photography.

### Technical Achievement

-   **Modular overlay architecture** with support for multiple overlay types
-   **Luminous overlay system** that attempts to use brightness patterns for camera detection
-   **QR code positioning** that attempts corner placement with blue channel modulation
-   **LSB steganography** for digital screenshot watermarking
-   **Composite rendering** that attempts to combine multiple overlay types
-   **Desktop capture optimization** with screenshot detection and preprocessing
-   **Multi-method extraction** with luminous, QR, and steganographic detection
-   **Parameter tuning** with 25.5% signal strength and adaptive thresholds
-   **Progressive extraction methods** with multiple fallback strategies
-   **End-to-end validation** with testing framework
-   **Performance protection** with timeout and infinite loop prevention

### Testing Innovation

-   **Round-trip validation**: Complete save→extract→verify workflow
-   **Desktop capture testing**: Testing with multiple opacity levels
-   **Progressive extraction testing**: Multiple extraction methods per test case
-   **Parameter validation**: Testing with optimized thresholds (0.1-0.9)
-   **Performance benchmarking**: Timing analysis and bottleneck identification
-   **Debug system**: Diagnostic and troubleshooting information
-   **Automated testing**: Scriptable validation for continuous integration

This system provides desktop identification with camera-resistant watermarking capabilities and testing infrastructure.
