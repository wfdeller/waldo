# Waldo Windows - Watermark System

A Windows implementation of the Waldo steganographic identification system with camera-detectable transparent overlays.

## Features

All core features from the macOS version, adapted for Windows:

### Modular Overlay Types
- **QR Code Overlays**: Corner-positioned QR codes with high error correction
- **Luminous Overlays**: Brightness-based corner markers for enhanced camera detection
- **Steganography Overlays**: Invisible LSB embedding in pixel data
- **Hybrid Overlays**: Combines QR codes, RGB patterns, and steganography
- **Beagle Overlays**: Wireframe patterns for testing and development

### Windows-Specific Features
- **WPF Transparent Overlays**: Nearly invisible watermarks using WPF transparency
- **Multi-Monitor Support**: Works across multiple Windows displays
- **Windows System Integration**: Uses WMI, Registry, and Windows APIs for system identification
- **Screen Capture API**: Native Windows screen capture using GDI32

## Quick Start

### 1. Build and Test

```cmd
# Build the application
dotnet build

# Run test suite to validate functionality
.\test_roundtrip.ps1
```

### 2. Start Camera-Resistant Overlay

```cmd
# Start camera-detectable overlay watermarking (default hybrid type)
waldo overlay start --daemon

# Start with specific overlay type for better camera detection
waldo overlay start luminous --daemon

# Start with luminous enhancement for better camera detection
waldo overlay start qr --luminous --daemon

# Check overlay status
waldo overlay status --verbose

# Stop overlay
waldo overlay stop
```

### 3. Test Camera Detection

```cmd
# Take a photo of your screen with your phone/camera
# Extract watermark from the camera photo
waldo extract C:\path\to\camera\photo.jpg --threshold 0.3 --verbose

# For desktop captures/screenshots
waldo extract C:\path\to\screenshot.png --threshold 0.2 --debug
```

## Commands

### Overlay Management

```cmd
# Start overlay with specific type
waldo overlay start [overlay-type] [--luminous] [--daemon] [--opacity 40] [--verbose] [--debug]

# Available overlay types:
waldo overlay start qr                    # QR codes only
waldo overlay start luminous              # Luminous brightness patterns
waldo overlay start steganography         # LSB steganography only
waldo overlay start hybrid               # QR + RGB + steganography (default)
waldo overlay start beagle               # Wireframe beagle (testing)

# Luminous enhancement flag:
waldo overlay start qr --luminous         # QR codes with luminous markers
waldo overlay start steganography --luminous # Steganography with luminous markers

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

```cmd
# Extract watermark from camera photo of screen
waldo extract "C:\path\to\camera\photo.jpg" --verbose

# Extract using simple LSB steganography (fast, for testing)
waldo extract "test.png" --simple-extraction --debug

# Extract with desktop parameters
waldo extract "screenshot.png" --threshold 0.3 --debug

# Extract with low threshold for difficult images
waldo extract "photo.jpg" --threshold 0.2 --no-screen-detection

# Extract with debug information
waldo extract "photo.jpg" --verbose --debug
```

## Project Structure

```
windows/
├── Waldo.sln                          # Visual Studio solution
├── src/
│   ├── Waldo.Core/                     # Cross-platform core logic
│   │   ├── SteganographyEngine.cs      # LSB steganography implementation
│   │   ├── WatermarkEngine.cs          # Multi-method watermark processing
│   │   └── WatermarkConstants.cs       # Shared constants and configuration
│   ├── Waldo.Windows/                  # Windows-specific implementations
│   │   ├── SystemInfo.cs               # Windows system information via WMI
│   │   ├── ScreenCapture.cs            # Windows screen capture via GDI32
│   │   ├── OverlayWindow.xaml          # WPF overlay window
│   │   ├── OverlayWindow.xaml.cs       # Overlay rendering logic
│   │   └── OverlayManager.cs           # Multi-monitor overlay management
│   └── Waldo.CLI/                      # Command line interface
│       └── Program.cs                  # System.CommandLine implementation
├── tests/
│   └── Waldo.Tests/                    # Unit tests
│       ├── SteganographyEngineTests.cs
│       └── SystemInfoTests.cs
└── test_roundtrip.ps1                 # PowerShell test suite
```

## Dependencies

### Core Libraries
- **.NET 8.0**: Target framework
- **SixLabors.ImageSharp**: Cross-platform image processing
- **QRCoder**: QR code generation
- **System.CommandLine**: Command-line parsing
- **System.Management**: Windows WMI access
- **System.Drawing.Common**: Windows GDI+ integration

### Windows-Specific
- **WPF (Windows Presentation Foundation)**: Transparent overlay windows
- **Windows Forms**: Screen information and multi-monitor support
- **GDI32**: Native screen capture APIs

## Building

### Prerequisites
- Windows 10/11
- .NET 8.0 SDK
- Visual Studio 2022 (recommended) or VS Code

### Build Commands

```cmd
# Restore dependencies
dotnet restore

# Build all projects
dotnet build

# Build specific configuration
dotnet build --configuration Release

# Run tests
dotnet test

# Publish self-contained executable
dotnet publish src/Waldo.CLI -c Release -r win-x64 --self-contained
```

## Testing

### Automated Testing

```powershell
# Run the full test suite
.\test_roundtrip.ps1

# Run with verbose output
.\test_roundtrip.ps1 -Verbose

# Run with debug information
.\test_roundtrip.ps1 -Debug

# Keep test files for inspection
.\test_roundtrip.ps1 -KeepFiles

# Run only edge case tests
.\test_roundtrip.ps1 -Verbose -Debug
```

### Manual Testing

```cmd
# Quick validation (30 seconds)
waldo overlay save-overlay quick.png --width 400 --height 300
waldo extract quick.png --simple-extraction

# Full validation (2 minutes)
waldo overlay save-overlay full.png --width 1024 --height 768 --debug
waldo extract full.png --simple-extraction --verbose --debug

# Performance benchmark
Measure-Command { waldo overlay save-overlay perf.png --width 1920 --height 1080 }
Measure-Command { waldo extract perf.png --simple-extraction }
```

### Camera-Resistant Watermarking Test

```cmd
# Test different overlay types for camera detection
waldo overlay start luminous --opacity 60           # Brightness-based
waldo overlay start qr --opacity 80                 # QR codes only
waldo overlay start hybrid --opacity 100            # Combined approach

# Take photo of screen with phone/camera
# Extract watermark from camera photo
waldo extract C:\path\to\camera_photo.jpg --verbose

# Expected output:
# Watermark detected!
# Username: your_username
# Computer-name: Your-Computer-Name
# Machine-uuid: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
# Timestamp: Dec 25, 2024 at 2:30:00 PM

# Clean up
waldo overlay stop
```

## Windows-Specific Implementation Details

### System Information
- **Username**: `Environment.UserName`
- **Computer Name**: `Environment.MachineName`
- **Machine UUID**: WMI `Win32_ComputerSystemProduct.UUID` with Registry fallback
- **Serial Number**: WMI `Win32_ComputerSystem.SerialNumber`

### Screen Capture
- **GDI32 APIs**: `BitBlt`, `CreateCompatibleDC`, `GetDesktopWindow`
- **Multi-Monitor**: `Screen.AllScreens` enumeration
- **Format Conversion**: GDI Bitmap → ImageSharp conversion pipeline

### Overlay Windows
- **WPF Transparency**: `AllowsTransparency="True"`, `Background="Transparent"`
- **Topmost Positioning**: `Topmost="True"`, `WindowStyle="None"`
- **Click-Through**: `IsHitTestVisible="False"`
- **Multi-Monitor**: Separate overlay window per screen

### Performance Optimizations
- **STA Threading**: Proper apartment state for WPF
- **Background Processing**: Hourly refresh timer
- **Memory Management**: Proper disposal of image resources
- **Exception Handling**: Graceful degradation for permission issues

## Compatibility

### Windows Versions
- **Windows 10**: Minimum version 1903 (build 18362)
- **Windows 11**: Full support
- **Windows Server**: 2019+ with Desktop Experience

### .NET Runtime
- **.NET 8.0**: Required runtime
- **Self-Contained**: Optional deployment without runtime dependency

### Hardware Requirements
- **RAM**: 512MB minimum, 1GB recommended
- **Display**: Any resolution, multi-monitor supported
- **Permissions**: No administrator rights required for basic operation

## Security Considerations

### Windows Security
- **No UAC Elevation**: Runs in user context
- **Local Processing**: All watermark processing done locally
- **No Network Dependencies**: Works completely offline
- **WMI Access**: Read-only system information queries
- **Registry Access**: Limited to machine GUID retrieval

### Steganographic Security
- **LSB Embedding**: Reliable bit-level embedding for digital screenshots
- **Multi-Method Redundancy**: Multiple embedding techniques prevent single-point failure
- **Camera-Resistant**: Survives camera capture, compression, and scaling
- **Invisible Watermarks**: Nearly imperceptible to human vision

## Troubleshooting

### Common Issues

1. **Overlay Not Visible**
   ```cmd
   waldo overlay debug-screen  # Check display configuration
   waldo overlay start --opacity 100  # Test with high opacity
   ```

2. **Extraction Failures**
   ```cmd
   waldo extract image.png --simple-extraction --debug  # Use simple method
   waldo extract image.png --threshold 0.1 --verbose    # Lower threshold
   ```

3. **Build Errors**
   ```cmd
   dotnet clean
   dotnet restore
   dotnet build --verbosity detailed
   ```

4. **Permission Issues**
   - Ensure Windows allows the application to run
   - Check Windows Defender exclusions if needed
   - Verify .NET 8.0 runtime is installed

## Performance

### Benchmarks (Windows 11, Intel i7)
- **Overlay Creation**: ~50ms (1920x1080)
- **Steganography Embedding**: ~30ms (800x600)
- **Watermark Extraction**: ~15ms (simple LSB)
- **Multi-Method Extraction**: ~100ms (full pipeline)
- **Memory Usage**: <50MB typical operation

### Optimization Tips
- Use `--simple-extraction` for faster watermark detection
- Lower resolution overlays for better performance
- Enable hardware acceleration for WPF rendering
- Use Release build for production deployment

## Contributing

### Development Setup
1. Clone the repository
2. Install .NET 8.0 SDK
3. Open `windows/Waldo.sln` in Visual Studio
4. Build and run tests

### Code Style
- Follow C# naming conventions
- Use XML documentation for public APIs
- Include unit tests for new functionality
- Test on multiple Windows versions

This Windows implementation provides full feature parity with the macOS version while leveraging Windows-specific APIs and frameworks for optimal performance and integration.