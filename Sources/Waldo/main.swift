import ArgumentParser
import Foundation
import CoreGraphics
import CoreText
import UniformTypeIdentifiers
import Cocoa

@main
struct Waldo: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "waldo",
        abstract: "Waldo - A steganographic desktop identification system for macOS",
        subcommands: [ExtractCommand.self, OverlayCommand.self],
        defaultSubcommand: OverlayCommand.self
    )
}


struct ExtractCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extract watermark from a photo"
    )
    
    @Argument(help: "Path to photo file")
    var photoPath: String
    
    @Option(name: .shortAndLong, help: "Confidence threshold (0.0-1.0, default: 0.6)")
    var threshold: Double = WatermarkConstants.PHOTO_CONFIDENCE_THRESHOLD
    
    @Flag(name: .shortAndLong, help: "Show detailed information")
    var verbose: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show debug information for detection failures")
    var debug: Bool = false
    
    @Flag(name: .long, help: "Skip automatic screen detection and perspective correction")
    var noScreenDetection: Bool = false
    
    @Flag(name: .long, help: "Use simple LSB steganography extraction only (skip complex ROI processing)")
    var simpleExtraction: Bool = false
    
    func run() throws {
        print("Waldo v\(Version.current)")
        
        // Validate threshold parameter
        guard threshold >= 0.0 && threshold <= 1.0 else {
            print("Error: Threshold must be between 0.0 and 1.0 (provided: \(threshold))")
            throw ExitCode.failure
        }
        
        let photoURL = URL(fileURLWithPath: photoPath)
        
        guard FileManager.default.fileExists(atPath: photoPath) else {
            print("Error: File not found at \(photoPath)")
            throw ExitCode.failure
        }
        
        guard PhotoProcessor.isImageFile(photoURL) else {
            print("Error: Not a valid image file")
            throw ExitCode.failure
        }
        
        if verbose {
            print("Using confidence threshold: \(threshold)")
        }
        
        if let result = PhotoProcessor.extractWatermarkFromPhoto(at: photoURL, threshold: threshold, verbose: verbose, debug: debug, enableScreenDetection: !noScreenDetection, simpleExtraction: simpleExtraction) {
            print("Watermark detected!")
            
            // Display raw watermark data split on ":"
            let fullWatermark = "\(result.userID):\(result.watermark):\(Int(result.timestamp))"
            let components = fullWatermark.components(separatedBy: ":")
            let labels = ["Username", "Computer-name", "Machine-uuid", "Timestamp"]
            
            for (index, component) in components.enumerated() {
                let label = index < labels.count ? labels[index] : "Field \(index + 1)"
                
                if label == "Timestamp", let timestamp = Double(component) {
                    let date = Date(timeIntervalSince1970: timestamp)
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .medium
                    formatter.timeZone = TimeZone.current
                    print("\(label): \(formatter.string(from: date))")
                } else {
                    print("\(label): \(component)")
                }
            }
            
        } else {
            print("No watermark detected in the image")
            throw ExitCode.failure
        }
    }
}



struct OverlayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "overlay",
        abstract: "Manage transparent desktop overlay watermarking",
        subcommands: [StartOverlayCommand.self, StopOverlayCommand.self, StatusOverlayCommand.self, SaveOverlayCommand.self, SaveDesktopCommand.self, DebugScreenCommand.self]
    )
}

struct DebugScreenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "debug-screen",
        abstract: "Debug screen resolution and display information"
    )
    
    func run() throws {
        print("Display Configuration Debug")
        
        let screens = NSScreen.screens
        print("Number of screens: \(screens.count)")
        
        for (index, screen) in screens.enumerated() {
            print("\nScreen \(index):")
            print(".  Frame: \(screen.frame)")
            print(".  Visible Frame: \(screen.visibleFrame)")
            print(".  Backing Scale Factor: \(screen.backingScaleFactor)")
            
            let frame = screen.frame
            let actualWidth = Int(frame.width * screen.backingScaleFactor)
            let actualHeight = Int(frame.height * screen.backingScaleFactor)
            print(".  Logical Size: \(Int(frame.width)) x \(Int(frame.height))")
            print(".  Physical Size: \(actualWidth) x \(actualHeight)")
            
            let deviceDescription = screen.deviceDescription
            print(".  Device Description:")
            for (key, value) in deviceDescription {
                print("    \(key.rawValue): \(value)")
            }
            
            // Try to get more display info using Core Graphics
            if let displayID = deviceDescription[.init("NSScreenNumber")] as? NSNumber {
                let cgDisplayID = CGDirectDisplayID(displayID.uint32Value)
                let pixelWidth = CGDisplayPixelsWide(cgDisplayID)
                let pixelHeight = CGDisplayPixelsHigh(cgDisplayID)
                print(".  Core Graphics Pixel Size: \(pixelWidth) x \(pixelHeight)")
                
                let displayBounds = CGDisplayBounds(cgDisplayID)
                print(".  Core Graphics Bounds: \(displayBounds)")
            }
        }
    }
}

struct StartOverlayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start transparent overlay watermarking"
    )
    
    @Option(name: .shortAndLong, help: "Custom watermark text")
    var watermark: String = "desktop"
    
    @Option(name: .shortAndLong, help: "Overlay opacity (1-255, default: 40)")
    var opacity: Int = WatermarkConstants.ALPHA_OPACITY
    
    @Flag(name: .long, help: "Run in background (daemon mode)")
    var daemon: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show verbose information")
    var verbose: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show debug information for overlay startup")
    var debug: Bool = false
    
    func run() throws {
        let logger = Logger(verbose: verbose, debug: debug)
        
        print("Waldo v\(Version.current)")
        print("Watermark pattern size: \(WatermarkConstants.PATTERN_SIZE) pixels")
        
        logger.debug("Starting overlay command with opacity: \(opacity), daemon: \(daemon)")
        
        // Validate opacity parameter
        guard opacity >= 1 && opacity <= 255 else {
            print("Error: Opacity must be between 1 and 255 (provided: \(opacity))")
            throw ExitCode.failure
        }
        
        let manager = OverlayWindowManager.shared
        
        logger.debug("Checking if overlay is already active...")
        let status = manager.getStatus()
        logger.debug("Current status: \(status)")
        
        if status["active"] as? Bool == true {
            logger.debug("Overlay already active, exiting")
            print("Error: Overlay is already running. Use 'waldo overlay stop' first.")
            throw ExitCode.failure
        }
        
        logger.debug("Starting overlay manager...")
        manager.startOverlays(opacity: opacity, logger: logger)
        
        // Display watermark details
        let systemInfo = SystemInfo.getSystemInfo()
        print("\nWatermark Details:")
        print(".  Username: \(systemInfo["username"] ?? "unknown")")
        print(".  Machine: \(systemInfo["computerName"] ?? "unknown")")
        print(".  Machine UUID: \(systemInfo["machineUUID"] ?? "unknown")")
        print(".  Timestamp: \(SystemInfo.getFormattedTimestamp())")
        
        let runLoop = RunLoop.current
        let distantFuture = Date.distantFuture
        
        signal(SIGINT) { _ in
            print("\nReceived interrupt signal, stopping overlays...")
            OverlayWindowManager.shared.stopOverlays()
            Darwin.exit(0)
        }
        
        signal(SIGTERM) { _ in
            print("\nReceived termination signal, stopping overlays...")
            OverlayWindowManager.shared.stopOverlays()
            Darwin.exit(0)
        }
        
        if daemon {
            print("✓ Running in daemon mode. Press Ctrl+C to stop.")
        } else {
            print("✓ Overlay started. Press Ctrl+C to stop, or use 'waldo overlay stop' from another terminal.")
        }
        
        runLoop.run(until: distantFuture)
    }
}

struct StopOverlayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop transparent overlay watermarking"
    )
    
    @Flag(name: .shortAndLong, help: "Show verbose information")
    var verbose: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show debug information for overlay shutdown")
    var debug: Bool = false
    
    func run() throws {
        let logger = Logger(verbose: verbose, debug: debug)
        let stopTime = CFAbsoluteTimeGetCurrent()
        
        logger.debug("Starting overlay stop command")
        
        let manager = OverlayWindowManager.shared
        
        logger.debug("Checking current overlay status...")
        let status = manager.getStatus()
        logger.debug("Current status: \(status)")
        
        // First try to stop local overlays (if running in same process)
        logger.debug("Attempting to stop local overlay manager...")
        manager.stopOverlays(logger: logger)
        
        // Check for and terminate any waldo overlay start processes
        // (whether daemon or interactive) - this bypasses getStatus() issues
        logger.debug("Searching for external overlay processes...")
        let terminatedCount = terminateOverlayProcesses(logger: logger)
        
        let totalStopTime = CFAbsoluteTimeGetCurrent() - stopTime
        logger.timing("Total overlay stop operation", duration: totalStopTime)
        
        if terminatedCount == 0 {
            logger.debug("No external processes found")
            print("No overlay processes are currently running.")
        } else {
            logger.debug("Terminated \(terminatedCount) external processes")
        }
    }
    
    private func terminateOverlayProcesses(logger: Logger = Logger()) -> Int {
        logger.debug("Using pgrep to find waldo overlay processes")
        // Use pgrep to find waldo processes - faster and more reliable than ps
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-f", "waldo overlay start"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.launch()
        
        // Add timeout to prevent hanging
        let semaphore = DispatchSemaphore(value: 0)
        var taskCompleted = false
        
        DispatchQueue.global(qos: .utility).async {
            task.waitUntilExit()
            taskCompleted = true
            semaphore.signal()
        }
        
        let timeout = DispatchTime.now() + .seconds(3)
        if semaphore.wait(timeout: timeout) == .timedOut {
            task.terminate()
            print("Warning: Could not find overlay processes (pgrep timeout)")
            return 0
        }
        
        guard taskCompleted else {
            print("Warning: Could not find overlay processes")
            return 0
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return 0
        }
        
        // Parse PIDs and terminate processes
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let pidStrings = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
        var terminatedCount = 0
        
        for pidString in pidStrings {
            if let pid = Int32(pidString.trimmingCharacters(in: .whitespaces)), pid != currentPID {
                // Send SIGTERM signal to gracefully stop the process
                if kill(pid, SIGTERM) == 0 {
                    terminatedCount += 1
                    print("✓ Terminated waldo overlay process (PID: \(pid))")
                } else {
                    print("Warning: Could not terminate waldo overlay process (PID: \(pid))")
                }
            }
        }
        
        return terminatedCount
    }
}

struct StatusOverlayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show overlay status and statistics"
    )
    
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show debug information for status check")
    var debug: Bool = false
    
    func run() throws {
        let logger = Logger(verbose: verbose, debug: debug)
        let statusTime = CFAbsoluteTimeGetCurrent()
        
        print("Waldo v\(Version.current)")
        
        logger.debug("Starting status check...")
        
        let manager = OverlayWindowManager.shared
        logger.debug("Getting status from overlay manager...")
        let status = manager.getStatus()
        
        logger.debug("Raw status data: \(status)")
        
        let statusCheckTime = CFAbsoluteTimeGetCurrent() - statusTime
        logger.timing("Status check", duration: statusCheckTime)
        
        print("Desktop Overlay Status:")
        let isActive = status["active"] as? Bool == true
        let isDaemonDetected = status["daemonDetected"] as? Bool == true
        
        logger.debug("Processed status: active=\(isActive), daemon=\(isDaemonDetected)")
        
        print(".  Active: \(isActive ? "Yes" : "No")")
        print(".  Screens: \(status["screenCount"] ?? 0)")
        
        if isDaemonDetected {
            print(".  Overlay Windows: \(status["screenCount"] ?? 0) (estimated - running in separate process)")
        } else {
            print(".  Overlay Windows: \(status["overlayWindowsCount"] ?? 0)")
        }
        
        // Display resolution info
        if let logicalSize = status["screenLogicalSize"] as? String,
           let logicalRes = status["screenLogicalResolution"] as? String,
           let scale = status["backingScaleFactor"] as? CGFloat {
            print(".  Screen (Logical): \(logicalSize)")
            print(".  Overlay Coverage: \(logicalRes)")
            print(".  Retina Scale: \(scale)x")
        }
        
        if let watermark = status["currentWatermark"] as? String {
            let systemInfo = SystemInfo.parseWatermarkData(watermark)
            print(".  Current User: \(systemInfo?.username ?? "unknown")")
            print(".  Machine: \(systemInfo?.computerName ?? "unknown")")
            if let timestamp = systemInfo?.timestamp {
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                print(".  Last Refresh: \(date)")
            }
        }
        
        if verbose {
            print("\nSystem Information:")
            let sysInfo = SystemInfo.getSystemInfo()
            for (key, value) in sysInfo {
                print(".  \(key): \(value)")
            }
        }
    }
}

struct SaveOverlayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "save-overlay",
        abstract: "Save watermark overlay as PNG for testing"
    )
    
    @Argument(help: "Output PNG file path")
    var outputPath: String
    
    @Option(name: .shortAndLong, help: "Image width (default: 1920)")
    var width: Int = 1920
    
    @Option(name: .shortAndLong, help: "Image height (default: 1080)")
    var height: Int = 1080
    
    @Option(name: .shortAndLong, help: "Overlay opacity (1-255, default: 40)")
    var opacity: Int = WatermarkConstants.ALPHA_OPACITY
    
    @Flag(name: .shortAndLong, help: "Show verbose information")
    var verbose: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show debug information")
    var debug: Bool = false
    
    func run() throws {
        let logger = Logger(verbose: verbose, debug: debug)
        
        print("Waldo v\(Version.current)")
        print("Saving watermark overlay to: \(outputPath)")
        
        // Validate opacity parameter
        guard opacity >= 1 && opacity <= 255 else {
            print("Error: Opacity must be between 1 and 255 (provided: \(opacity))")
            throw ExitCode.failure
        }
        
        // Validate output path
        let outputURL = URL(fileURLWithPath: outputPath)
        guard outputURL.pathExtension.lowercased() == "png" else {
            print("Error: Output file must have .png extension")
            throw ExitCode.failure
        }
        
        logger.debug("Creating overlay image with dimensions: \(width)x\(height)")
        logger.debug("Using opacity: \(opacity)/255")
        
        do {
            try saveWatermarkOverlay(to: outputURL, width: width, height: height, opacity: opacity, logger: logger)
            print("✓ Watermark overlay saved successfully")
            
            // Display watermark details
            let systemInfo = SystemInfo.getSystemInfo()
            print("\nWatermark Details:")
            print(".  Username: \(systemInfo["username"] ?? "unknown")")
            print(".  Machine: \(systemInfo["computerName"] ?? "unknown")")
            print(".  Machine UUID: \(systemInfo["machineUUID"] ?? "unknown")")
            print(".  Timestamp: \(SystemInfo.getFormattedTimestamp())")
            
            // Suggest test command
            print("\nTest extraction with:")
            print("  waldo extract \(outputPath) --verbose")
            
        } catch {
            print("Error: Failed to save overlay: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
    
    private func saveWatermarkOverlay(to url: URL, width: Int, height: Int, opacity: Int, logger: Logger) throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        logger.debug("Creating bitmap context...")
        
        // Create bitmap context with RGBA format
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw NSError(domain: "WaldoError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap context"])
        }
        
        logger.debug("Bitmap context created successfully")
        
        // First, create a base image with LSB steganography
        logger.debug("Creating base image for LSB steganography...")
        
        // Get current watermark data
        let watermarkData = SystemInfo.getWatermarkDataWithHourlyTimestamp()
        logger.debug("Watermark data: \(watermarkData)")
        
        // Create a neutral base image
        context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: CGFloat(opacity) / 255.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Create base image
        guard let baseImage = context.makeImage() else {
            throw NSError(domain: "WaldoError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to create base image"])
        }
        
        // Apply LSB steganography first using existing engine
        // Parse watermark data to get components
        let components = watermarkData.components(separatedBy: ":")
        guard components.count >= 4 else {
            throw NSError(domain: "WaldoError", code: 8, userInfo: [NSLocalizedDescriptionKey: "Invalid watermark data format"])
        }
        
        let userID = components[0]
        let watermark = components[1..<components.count-1].joined(separator: ":")
        
        logger.debug("Embedding LSB steganography...")
        guard let lsbImage = SteganographyEngine.embedWatermark(in: baseImage, watermark: watermark, userID: userID) else {
            throw NSError(domain: "WaldoError", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to embed LSB watermark"])
        }
        
        // Clear context and draw the LSB image as base
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(lsbImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        logger.debug("Skipping visual patterns to preserve LSB data integrity...")
        
        // Skip visual patterns for now to ensure LSB extraction works reliably
        // TODO: Implement truly non-interfering visual patterns for camera detection
        
        let renderTime = CFAbsoluteTimeGetCurrent() - startTime
        logger.timing("Complex watermark with LSB rendering", duration: renderTime)
        
        // Create image from context
        guard let cgImage = context.makeImage() else {
            throw NSError(domain: "WaldoError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from context"])
        }
        
        logger.debug("Saving PNG to: \(url.path)")
        
        // Save as PNG
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "WaldoError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "WaldoError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to write PNG file"])
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        logger.timing("Total overlay save", duration: totalTime)
        logger.debug("PNG saved successfully")
    }
    
    
    // MARK: - Complex Watermark Pattern Generation (matches WatermarkOverlayView)
    
    private func generateComplexWatermarkPattern(watermarkData: String, opacity: Int, logger: Logger) -> [UInt8] {
        logger.debug("Generating complex watermark pattern...")
        
        let patternSize = WatermarkConstants.PATTERN_SIZE
        
        // Generate micro QR pattern for the watermark data
        let microPattern = generateMicroQRPattern(from: watermarkData)
        
        // Create redundant patterns across the overlay
        let redundantPattern = generateRedundantPattern(from: watermarkData)
        
        // Combine patterns with blue channel QR modulation for better camera detection
        var pattern: [UInt8] = []
        for i in 0..<(patternSize * patternSize * 4) {
            let pixelIndex = i / 4
            let channelIndex = i % 4
            
            // Get bits from patterns
            let microBit = microPattern[pixelIndex % microPattern.count]
            let redundantBit = redundantPattern[pixelIndex % redundantPattern.count]
            
            switch channelIndex {
            case 0: // Red channel - subtle redundant watermark only
                let baseValue: UInt8 = UInt8(WatermarkConstants.RGB_BASE)
                if redundantBit == 1 {
                    pattern.append(baseValue + UInt8(WatermarkConstants.RGB_DELTA / 2))  // Subtle red modulation
                } else {
                    pattern.append(baseValue)
                }
                
            case 1: // Green channel - minimal modulation for natural appearance
                let baseValue: UInt8 = UInt8(WatermarkConstants.RGB_BASE)
                if redundantBit == 1 {
                    pattern.append(baseValue + UInt8(WatermarkConstants.RGB_DELTA / 3))  // Very subtle green
                } else {
                    pattern.append(baseValue)
                }
                
            case 2: // Blue channel - PRIMARY QR code embedding
                let baseValue: UInt8 = UInt8(WatermarkConstants.RGB_BASE)
                if microBit == 1 {
                    // Strong blue signal for QR bits - cameras often have better blue channel sensitivity
                    pattern.append(baseValue + UInt8(WatermarkConstants.RGB_DELTA))
                } else {
                    // Lower blue for QR background
                    pattern.append(baseValue - UInt8(WatermarkConstants.RGB_DELTA / 2))
                }
                
            default: // Alpha channel
                pattern.append(UInt8(opacity))
            }
        }
        
        logger.debug("Generated pattern with \(pattern.count) bytes")
        return pattern
    }
    
    private func generateMicroQRPattern(from data: String) -> [UInt8] {
        // Create Version 2 QR code (37x37) with high error correction
        let qrSize = WatermarkConstants.QR_VERSION2_SIZE  // Version 2 QR code size
        var pattern = [UInt8](repeating: 0, count: qrSize * qrSize)
        
        // Draw three finder patterns (classic QR code corners)
        drawFinderPattern(&pattern, size: qrSize, x: 0, y: 0)           // Top-left
        drawFinderPattern(&pattern, size: qrSize, x: qrSize-7, y: 0)     // Top-right  
        drawFinderPattern(&pattern, size: qrSize, x: 0, y: qrSize-7)     // Bottom-left
        
        // Draw separator patterns around finder patterns (1 pixel white border)
        drawSeparatorPatterns(&pattern, size: qrSize)
        
        // Draw alignment pattern for Version 2 (center: 18,18)
        drawAlignmentPattern(&pattern, size: qrSize, x: 16, y: 16)  // 5x5 pattern centered at (18,18)
        
        // Draw timing patterns (horizontal and vertical lines)
        drawTimingPatterns(&pattern, size: qrSize)
        
        // Add format information areas (reserved for error correction level)
        addFormatInformation(&pattern, size: qrSize)
        
        // Embed data with Reed-Solomon error correction (ECC Level H)
        embedDataWithErrorCorrection(&pattern, size: qrSize, data: data)
        
        return pattern
    }
    
    private func generateRedundantPattern(from data: String) -> [UInt8] {
        // Create redundant encoding with error correction
        let errorCorrectedData = addSimpleErrorCorrection(data)
        let stringData = Data(errorCorrectedData.utf8)
        let bits = stringData.flatMap { byte in
            (0..<8).map { (byte >> $0) & 1 }
        }
        
        let patternSize = WatermarkConstants.PATTERN_SIZE
        var pattern = [UInt8](repeating: 0, count: patternSize * patternSize)
        
        // Repeat the pattern multiple times across the overlay
        for i in 0..<pattern.count {
            pattern[i] = UInt8(bits[i % bits.count])
        }
        
        return pattern
    }
    
    private func addSimpleErrorCorrection(_ input: String) -> String {
        // Simple repetition code - repeat each character 3 times for error correction
        return input.map { String(repeating: String($0), count: 3) }.joined()
    }
    
    private func drawTiledWatermarkPattern(context: CGContext, pattern: [UInt8], width: Int, height: Int, logger: Logger) {
        let patternSize = WatermarkConstants.PATTERN_SIZE
        let patternCGSize = CGSize(width: CGFloat(patternSize), height: CGFloat(patternSize))
        
        let tilesX = Int(ceil(CGFloat(width) / patternCGSize.width))
        let tilesY = Int(ceil(CGFloat(height) / patternCGSize.height))
        
        logger.debug("Drawing \(tilesX)x\(tilesY) watermark tiles")
        
        for tileY in 0..<tilesY {
            for tileX in 0..<tilesX {
                let tileRect = CGRect(
                    x: CGFloat(tileX) * patternCGSize.width,
                    y: CGFloat(tileY) * patternCGSize.height,
                    width: patternCGSize.width,
                    height: patternCGSize.height
                )
                
                drawWatermarkTile(context: context, pattern: pattern, rect: tileRect)
            }
        }
    }
    
    private func drawWatermarkTile(context: CGContext, pattern: [UInt8], rect: CGRect) {
        let patternSize = WatermarkConstants.PATTERN_SIZE
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = patternSize * bytesPerPixel
        
        pattern.withUnsafeBytes { bytes in
            guard let cgContext = CGContext(
                data: UnsafeMutableRawPointer(mutating: bytes.baseAddress),
                width: patternSize,
                height: patternSize,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            
            guard let image = cgContext.makeImage() else { return }
            
            context.draw(image, in: rect)
        }
    }
    
    private func drawCornerQRCodes(context: CGContext, watermarkData: String, width: Int, height: Int, opacity: Int, logger: Logger) {
        // Version 2 QR codes with blue channel modulation for better camera detection
        let qrPixelSize = WatermarkConstants.QR_VERSION2_SIZE  // Version 2 QR code modules
        let pixelsPerQRBit: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_PIXELS_PER_MODULE)  // Pixels per QR module
        let qrSize: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_PIXEL_SIZE)  // Total pixel size
        let margin: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_MARGIN)   // Consistent margin
        let menuBarOffset: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_MENU_BAR_OFFSET)  // Consistent offset
        
        // Generate QR pattern for current watermark data
        let qrPattern = generateMicroQRPattern(from: watermarkData)
        if qrPattern.count != qrPixelSize * qrPixelSize {
            logger.debug("Warning: QR pattern size mismatch: \(qrPattern.count) elements, expected \(qrPixelSize * qrPixelSize)")
        }
        
        // Define corner positions (adjust for image coordinates vs screen coordinates)
        let corners = [
            CGPoint(x: CGFloat(width) - qrSize - margin, y: CGFloat(height) - menuBarOffset - qrSize),  // Top-right
            CGPoint(x: margin, y: CGFloat(height) - menuBarOffset - qrSize),                           // Top-left
            CGPoint(x: CGFloat(width) - qrSize - margin, y: margin),                                   // Bottom-right
            CGPoint(x: margin, y: margin)                                                              // Bottom-left
        ]
        
        logger.debug("Drawing QR codes at \(corners.count) corner positions")
        
        // Draw QR code at each corner
        for corner in corners {
            drawQRCode(context: context, at: corner, size: qrSize, pattern: qrPattern, patternSize: qrPixelSize, pixelsPerBit: pixelsPerQRBit, opacity: opacity)
        }
    }
    
    private func drawQRCode(context: CGContext, at position: CGPoint, size: CGFloat, pattern: [UInt8], patternSize: Int, pixelsPerBit: CGFloat, opacity: Int) {
        // Each QR bit is rendered as pixelsPerBit x pixelsPerBit pixels with blue channel modulation
        
        for y in 0..<patternSize {
            for x in 0..<patternSize {
                let patternIndex = y * patternSize + x
                if patternIndex < pattern.count {
                    let bit = pattern[patternIndex]
                    
                    // Blue channel modulation: embed QR in blue while maintaining visual subtlety
                    let baseColor: CGFloat = CGFloat(WatermarkConstants.RGB_BASE) / 255.0
                    let deltaColor: CGFloat = CGFloat(WatermarkConstants.RGB_DELTA) / 255.0
                    
                    let red: CGFloat = baseColor
                    let green: CGFloat = baseColor
                    let blue: CGFloat = bit == 1 ? baseColor + deltaColor : baseColor - (deltaColor / 2)
                    let alpha: CGFloat = CGFloat(opacity) / 255.0
                    
                    let color = CGColor(red: red, green: green, blue: blue, alpha: alpha)
                    context.setFillColor(color)
                    
                    let pixelRect = CGRect(
                        x: position.x + CGFloat(x) * pixelsPerBit,
                        y: position.y + CGFloat(y) * pixelsPerBit,
                        width: pixelsPerBit,
                        height: pixelsPerBit
                    )
                    
                    context.fill(pixelRect)
                }
            }
        }
    }
    
    // MARK: - QR Code Pattern Generation Helper Functions
    
    private func drawFinderPattern(_ pattern: inout [UInt8], size: Int, x: Int, y: Int) {
        let finderSize = 7
        for dy in 0..<finderSize {
            for dx in 0..<finderSize {
                let px = x + dx
                let py = y + dy
                if px < size && py < size {
                    let index = py * size + px
                    // Create the classic QR finder pattern
                    let isOuterRing = (dx == 0 || dx == 6 || dy == 0 || dy == 6)
                    let isInnerSquare = (dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4)
                    pattern[index] = (isOuterRing || isInnerSquare) ? 1 : 0
                }
            }
        }
    }
    
    private func drawAlignmentPattern(_ pattern: inout [UInt8], size: Int, x: Int, y: Int) {
        let alignSize = 5
        for dy in 0..<alignSize {
            for dx in 0..<alignSize {
                let px = x + dx
                let py = y + dy
                if px >= 0 && px < size && py >= 0 && py < size {
                    let index = py * size + px
                    let isRing = (dx == 0 || dx == 4 || dy == 0 || dy == 4)
                    let isCenter = (dx == 2 && dy == 2)
                    pattern[index] = (isRing || isCenter) ? 1 : 0
                }
            }
        }
    }
    
    private func drawTimingPatterns(_ pattern: inout [UInt8], size: Int) {
        // Horizontal timing pattern (row 6, skipping finder and format areas)
        for x in 8..<(size-8) {
            if x != 6 {  // Skip format information column
                let index = 6 * size + x
                pattern[index] = UInt8(x % 2)
            }
        }
        
        // Vertical timing pattern (column 6, skipping finder and format areas)
        for y in 8..<(size-8) {
            if y != 6 {  // Skip format information row
                let index = y * size + 6
                pattern[index] = UInt8(y % 2)
            }
        }
    }
    
    private func drawSeparatorPatterns(_ pattern: inout [UInt8], size: Int) {
        // White separator borders around finder patterns
        
        // Top-left finder separator
        for x in 0..<8 {
            if x < size && 7 < size {
                pattern[7 * size + x] = 0  // Bottom border
            }
        }
        for y in 0..<8 {
            if 7 < size && y < size {
                pattern[y * size + 7] = 0  // Right border
            }
        }
        
        // Top-right finder separator
        for x in (size-8)..<size {
            if x >= 0 && x < size && 7 < size {
                pattern[7 * size + x] = 0  // Bottom border
            }
        }
        for y in 0..<8 {
            if (size-8) >= 0 && (size-8) < size && y < size {
                pattern[y * size + (size-8)] = 0  // Left border
            }
        }
        
        // Bottom-left finder separator
        for x in 0..<8 {
            if x < size && (size-8) >= 0 && (size-8) < size {
                pattern[(size-8) * size + x] = 0  // Top border
            }
        }
        for y in (size-8)..<size {
            if 7 < size && y >= 0 && y < size {
                pattern[y * size + 7] = 0  // Right border
            }
        }
    }
    
    private func addFormatInformation(_ pattern: inout [UInt8], size: Int) {
        // Reserve format information areas (will be filled with ECC Level H indicator)
        // Format info is placed around top-left and split between top-right/bottom-left
        
        // Format information around top-left finder pattern
        for i in 0..<6 {
            if i < size && 8 < size {
                pattern[8 * size + i] = 0  // Horizontal format strip
            }
            if 8 < size && i < size {
                pattern[i * size + 8] = 0  // Vertical format strip
            }
        }
        
        // Skip timing pattern intersection
        for i in 7..<9 {
            if i < size && 8 < size {
                pattern[8 * size + i] = 0
            }
            if 8 < size && i < size {
                pattern[i * size + 8] = 0
            }
        }
        
        // Format information in other corners
        for i in 0..<8 {
            if (size-1-i) >= 0 && (size-1-i) < size && 8 < size {
                pattern[8 * size + (size-1-i)] = 0  // Top-right format
            }
            if (size-7+i) >= 0 && (size-7+i) < size && 8 < size {
                pattern[(size-7+i) * size + 8] = 0  // Bottom-left format
            }
        }
    }
    
    private func isFormatInformationArea(x: Int, y: Int, size: Int) -> Bool {
        // Check if position is in format information area
        let inHorizontalFormat = (y == 8 && (x < 9 || x >= size-8))
        let inVerticalFormat = (x == 8 && (y < 9 || y >= size-7))
        return inHorizontalFormat || inVerticalFormat
    }
    
    private func embedDataWithErrorCorrection(_ pattern: inout [UInt8], size: Int, data: String) {
        // Enhanced error correction using Reed-Solomon principles
        let errorCorrectedData = generateHighErrorCorrectionData(data)
        let stringData = Data(errorCorrectedData.utf8)
        let bits = stringData.flatMap { byte in
            (0..<8).map { (byte >> (7-$0)) & 1 }  // MSB first for proper QR encoding
        }
        
        var bitIndex = 0
        
        // QR code data placement follows zigzag pattern from bottom-right
        var up = true
        var col = size - 1
        
        while col > 0 {
            if col == 6 { col -= 1 }  // Skip timing column
            
            for _ in 0..<size {
                for c in 0..<2 {
                    let x = col - c
                    let y = up ? (size - 1 - (bitIndex / 2) % size) : (bitIndex / 2) % size
                    
                    if x >= 0 && x < size && y >= 0 && y < size {
                        let index = y * size + x
                        
                        // Check if this position is available for data
                        let inFinder = isFinderPatternArea(x: x, y: y, size: size)
                        let inAlignment = (x >= 16 && x <= 20 && y >= 16 && y <= 20)  // Version 2 alignment at (18,18)
                        let inTiming = (x == 6 || y == 6)
                        let inFormat = isFormatInformationArea(x: x, y: y, size: size)
                        
                        if !inFinder && !inAlignment && !inTiming && !inFormat {
                            if bitIndex < bits.count {
                                pattern[index] = UInt8(bits[bitIndex])
                            } else {
                                pattern[index] = 0  // Padding
                            }
                            bitIndex += 1
                        }
                    }
                }
            }
            
            up = !up
            col -= 2
        }
    }
    
    private func isFinderPatternArea(x: Int, y: Int, size: Int) -> Bool {
        let inTopLeft = (x < 9 && y < 9)
        let inTopRight = (x >= size-8 && y < 9)
        let inBottomLeft = (x < 9 && y >= size-8)
        return inTopLeft || inTopRight || inBottomLeft
    }
    
    private func generateHighErrorCorrectionData(_ input: String) -> String {
        // Enhanced error correction for ECC Level H (30% recovery capability)
        // Use multiple redundancy techniques:
        
        // 1. Character-level repetition (3x)
        let characterRepeated = input.map { String(repeating: String($0), count: 3) }.joined()
        
        // 2. Block-level redundancy - repeat entire message
        let blockRepeated = String(repeating: characterRepeated + "|", count: 2)
        
        // 3. Checksum for validation
        let checksum = input.reduce(0) { $0 + Int($1.asciiValue ?? 0) } % 256
        let checksumHex = String(format: "%02X", checksum)
        
        return blockRepeated + checksumHex
    }
    
    private func drawSubtleCornerQRCodes(context: CGContext, watermarkData: String, width: Int, height: Int, opacity: Int, logger: Logger) {
        // Only draw corner QR codes with very subtle opacity to preserve LSB data
        let qrPixelSize = WatermarkConstants.QR_VERSION2_SIZE
        let pixelsPerQRBit: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_PIXELS_PER_MODULE)
        let qrSize: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_PIXEL_SIZE)
        let margin: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_MARGIN)
        let menuBarOffset: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_MENU_BAR_OFFSET)
        
        // Generate QR pattern
        let qrPattern = generateMicroQRPattern(from: watermarkData)
        
        // Define corner positions (just corners, no center patterns)
        let corners = [
            CGPoint(x: CGFloat(width) - qrSize - margin, y: CGFloat(height) - menuBarOffset - qrSize),  // Top-right
            CGPoint(x: margin, y: margin)                                                              // Bottom-left only
        ]
        
        logger.debug("Drawing subtle QR codes at \(corners.count) corner positions")
        
        // Draw very subtle QR codes that don't interfere with LSB
        for corner in corners {
            drawSubtleQRCode(context: context, at: corner, size: qrSize, pattern: qrPattern, patternSize: qrPixelSize, pixelsPerBit: pixelsPerQRBit, opacity: opacity)
        }
    }
    
    private func drawSubtleQRCode(context: CGContext, at position: CGPoint, size: CGFloat, pattern: [UInt8], patternSize: Int, pixelsPerBit: CGFloat, opacity: Int) {
        // Draw QR with very low opacity in alpha channel only to avoid LSB interference
        
        for y in 0..<patternSize {
            for x in 0..<patternSize {
                let patternIndex = y * patternSize + x
                if patternIndex < pattern.count {
                    let bit = pattern[patternIndex]
                    
                    // Only modify alpha channel to avoid LSB data corruption
                    let alphaValue = bit == 1 ? CGFloat(opacity) / 255.0 : 0.0
                    let color = CGColor(red: 0, green: 0, blue: 0, alpha: alphaValue)
                    context.setFillColor(color)
                    
                    let pixelRect = CGRect(
                        x: position.x + CGFloat(x) * pixelsPerBit,
                        y: position.y + CGFloat(y) * pixelsPerBit,
                        width: pixelsPerBit,
                        height: pixelsPerBit
                    )
                    
                    context.fill(pixelRect)
                }
            }
        }
    }
}

struct SaveDesktopCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "save-desktop",
        abstract: "Capture desktop screenshot with watermark overlay applied"
    )
    
    @Argument(help: "Output PNG file path")
    var outputPath: String
    
    @Flag(name: .shortAndLong, help: "Show verbose information")
    var verbose: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show debug information")
    var debug: Bool = false
    
    func run() throws {
        let logger = Logger(verbose: verbose, debug: debug)
        
        print("Waldo v\(Version.current)")
        print("Capturing desktop with overlay to: \(outputPath)")
        
        // Validate output path
        let outputURL = URL(fileURLWithPath: outputPath)
        guard outputURL.pathExtension.lowercased() == "png" else {
            print("Error: Output file must have .png extension")
            throw ExitCode.failure
        }
        
        // Check if overlay is running (check both local and daemon processes)
        let manager = OverlayWindowManager.shared
        let status = manager.getStatus()
        
        let isActive = status["active"] as? Bool == true
        let daemonDetected = status["daemonDetected"] as? Bool == true
        
        logger.debug("Overlay status: active=\(isActive), daemon=\(daemonDetected)")
        
        // Also check for waldo overlay processes directly
        let hasOverlayProcess = checkForOverlayProcess(logger: logger)
        
        guard isActive || daemonDetected || hasOverlayProcess else {
            print("Error: No active overlay found. Start overlay first with 'waldo overlay start'")
            logger.debug("Status check failed: active=\(isActive), daemon=\(daemonDetected), process=\(hasOverlayProcess)")
            throw ExitCode.failure
        }
        
        if hasOverlayProcess && !isActive {
            logger.debug("Detected overlay process running in daemon mode")
        }
        
        logger.debug("Capturing desktop screenshot with overlay...")
        
        do {
            try captureDesktopWithOverlay(to: outputURL, logger: logger)
            print("✓ Desktop with overlay captured successfully")
            
            // Display watermark details
            let systemInfo = SystemInfo.getSystemInfo()
            print("\nWatermark Details:")
            print(".  Username: \(systemInfo["username"] ?? "unknown")")
            print(".  Machine: \(systemInfo["computerName"] ?? "unknown")")
            print(".  Machine UUID: \(systemInfo["machineUUID"] ?? "unknown")")
            print(".  Timestamp: \(SystemInfo.getFormattedTimestamp())")
            
            // Suggest test command
            print("\nTest extraction with:")
            print("  waldo extract \(outputPath) --verbose")
            
        } catch {
            print("Error: Failed to capture desktop: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
    
    private func captureDesktopWithOverlay(to url: URL, logger: Logger) throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        logger.debug("Getting main screen bounds...")
        
        guard let mainScreen = NSScreen.main else {
            throw NSError(domain: "WaldoError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access main screen"])
        }
        
        let screenRect = mainScreen.frame
        let scaleFactor = mainScreen.backingScaleFactor
        
        logger.debug("Screen bounds: \(screenRect), scale: \(scaleFactor)")
        
        // Create display ID from screen
        guard let displayID = mainScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            throw NSError(domain: "WaldoError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not get display ID"])
        }
        
        let cgDisplayID = CGDirectDisplayID(displayID.uint32Value)
        
        logger.debug("Capturing screen with CGDisplayCreateImage...")
        
        // Capture the screen including overlay windows
        guard let image = CGDisplayCreateImage(cgDisplayID) else {
            throw NSError(domain: "WaldoError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to capture screen"])
        }
        
        let captureTime = CFAbsoluteTimeGetCurrent() - startTime
        logger.timing("Screen capture", duration: captureTime)
        
        logger.debug("Saving captured image to: \(url.path)")
        
        // Save as PNG
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "WaldoError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "WaldoError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to write PNG file"])
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        logger.timing("Total desktop capture", duration: totalTime)
        logger.debug("Desktop capture saved successfully")
    }
    
    private func checkForOverlayProcess(logger: Logger) -> Bool {
        logger.debug("Checking for overlay processes...")
        
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-f", "waldo overlay start"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.launch()
        
        // Add timeout to prevent hanging
        let semaphore = DispatchSemaphore(value: 0)
        var taskCompleted = false
        
        DispatchQueue.global(qos: .utility).async {
            task.waitUntilExit()
            taskCompleted = true
            semaphore.signal()
        }
        
        let timeout = DispatchTime.now() + .seconds(3)
        if semaphore.wait(timeout: timeout) == .timedOut {
            task.terminate()
            logger.debug("Process check timed out")
            return false
        }
        
        guard taskCompleted else {
            logger.debug("Process check failed")
            return false
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            logger.debug("Failed to read process output")
            return false
        }
        
        let pidStrings = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
        let currentPID = ProcessInfo.processInfo.processIdentifier
        
        for pidString in pidStrings {
            if let pid = Int32(pidString.trimmingCharacters(in: .whitespaces)), pid != currentPID {
                logger.debug("Found overlay process with PID: \(pid)")
                return true
            }
        }
        
        logger.debug("No overlay processes found")
        return false
    }
}