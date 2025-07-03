import ArgumentParser
import Foundation
import CoreGraphics
import CoreText
import UniformTypeIdentifiers
import Cocoa

// Custom error types for more specific feedback
enum WaldoError: Error, CustomStringConvertible {
    case invalidThreshold(Double)
    case fileNotFound(String)
    case invalidImageFile(String)
    case noWatermarkDetected
    case overlayAlreadyRunning
    case invalidOpacity(Int)
    case invalidOutputPath(String)
    case noActiveOverlay
    case failedToSaveOverlay(Error)
    case failedToCaptureDesktop(Error)
    case invalidTileSize(Int)
    case invalidLineWidth(Int)
    case invalidOpacityPercentage(Double)
    case failedToStartBeagleOverlay(Error)

    var description: String {
        switch self {
        case .invalidThreshold(let value):
            return "Error: Threshold must be between 0.0 and 1.0 (provided: \(value))"
        case .fileNotFound(let path):
            return "Error: File not found at \(path)"
        case .invalidImageFile(let path):
            return "Error: Not a valid image file at \(path)"
        case .noWatermarkDetected:
            return "No watermark detected in the image."
        case .overlayAlreadyRunning:
            return "Error: Overlay is already running. Use 'waldo overlay stop' first."
        case .invalidOpacity(let value):
            return "Error: Opacity must be between 1 and 255 (provided: \(value))"
        case .invalidOutputPath(let path):
            return "Error: Output file must have .png extension. Provided: \(path)"
        case .noActiveOverlay:
            return "Error: No active overlay found. Start overlay first with 'waldo overlay start'"
        case .failedToSaveOverlay(let error):
            return "Error: Failed to save overlay: \(error.localizedDescription)"
        case .failedToCaptureDesktop(let error):
            return "Error: Failed to capture desktop: \(error.localizedDescription)"
        case .invalidTileSize(let value):
            return "Error: Tile size must be between 50 and 500 pixels (provided: \(value))"
        case .invalidLineWidth(let value):
            return "Error: Line width must be between 1 and 10 pixels (provided: \(value))"
        case .invalidOpacityPercentage(let value):
            return "Error: Opacity must be between 0.1 and 100 percent (provided: \(value))"
        case .failedToStartBeagleOverlay(let error):
            return "Error: Failed to start overlay - \(error.localizedDescription)"
        }
    }
}

@main
struct Waldo: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "waldo",
        abstract: "A steganographic desktop identification system for macOS.",
        subcommands: [ExtractCommand.self, OverlayCommand.self],
        defaultSubcommand: OverlayCommand.self
    )
}

struct ExtractCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extract a watermark from a photo."
    )

    @Argument(help: "Path to the photo file to extract a watermark from.")
    var photoPath: String

    @Option(name: .shortAndLong, help: "The confidence threshold for watermark detection (0.0 to 1.0).")
    var threshold: Double = WatermarkConstants.PHOTO_CONFIDENCE_THRESHOLD

    @Flag(name: .shortAndLong, help: "Show detailed information during extraction.")
    var verbose: Bool = false

    @Flag(name: .shortAndLong, help: "Show debugging information for detection failures.")
    var debug: Bool = false

    @Flag(name: .long, help: "Disable automatic screen detection and perspective correction.")
    var noScreenDetection: Bool = false

    @Flag(name: .long, help: "Use only the simple LSB steganography extraction method.")
    var simpleExtraction: Bool = false

    func run() throws {
        print("Waldo v\(Version.current)")

        guard threshold >= 0.0 && threshold <= 1.0 else {
            throw WaldoError.invalidThreshold(threshold)
        }

        let photoURL = URL(fileURLWithPath: photoPath)

        guard FileManager.default.fileExists(atPath: photoPath) else {
            throw WaldoError.fileNotFound(photoPath)
        }

        guard PhotoProcessor.isImageFile(photoURL) else {
            throw WaldoError.invalidImageFile(photoPath)
        }

        if verbose {
            print("Using confidence threshold: \(threshold)")
        }

        if let result = PhotoProcessor.extractWatermarkFromPhoto(at: photoURL, threshold: threshold, verbose: verbose, debug: debug, enableScreenDetection: !noScreenDetection, simpleExtraction: simpleExtraction) {
            print("Watermark detected!")

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
            throw WaldoError.noWatermarkDetected
        }
    }
}

struct OverlayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "overlay",
        abstract: "Manage the transparent desktop overlay watermark.",
        subcommands: [StartOverlayCommand.self, StopOverlayCommand.self, StatusOverlayCommand.self, SaveOverlayCommand.self, SaveDesktopCommand.self, DebugScreenCommand.self, OverlaySampleCommand.self]
    )
}

struct DebugScreenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "debug-screen",
        abstract: "Debug screen resolution and display information."
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
        abstract: "Start the transparent overlay watermark."
    )

    @Argument(help: "The overlay type to use. Available types: qr, luminous, steganography, hybrid, beagle. Defaults to 'hybrid'.")
    var overlayType: String?

    @Option(name: .shortAndLong, help: "The opacity of the overlay, from 1 (nearly transparent) to 255 (fully opaque).")
    var opacity: Int = WatermarkConstants.ALPHA_OPACITY

    @Flag(name: .long, help: "Run the overlay as a background process (daemon).")
    var daemon: Bool = false

    @Flag(name: .shortAndLong, help: "Show verbose information during startup.")
    var verbose: Bool = false

    @Flag(name: .shortAndLong, help: "Show debugging information for overlay startup.")
    var debug: Bool = false
    
    @Flag(name: .long, help: "Add luminous corner markers to enhance detection and calibration.")
    var luminous: Bool = false

    func run() throws {
        let logger = Logger(verbose: verbose, debug: debug)
        
        print("Waldo v\(Version.current)")
        
        // Parse overlay type
        let type: OverlayType
        if let overlayTypeString = overlayType {
            guard let parsedType = OverlayType.from(string: overlayTypeString) else {
                throw OverlayTypeError(invalidType: overlayTypeString)
            }
            type = parsedType
        } else {
            type = OverlayType.defaultType
        }
        
        print("Using overlay type: \(type.rawValue)")
        print("  - \(type.description)")
        
        logger.debug("Starting overlay command with type: \(type), luminous: \(luminous), opacity: \(opacity), daemon: \(daemon)")
        
        guard opacity >= 1 && opacity <= 255 else {
            throw WaldoError.invalidOpacity(opacity)
        }
        
        // Validate parameters for the overlay type
        let renderer = OverlayRendererFactory.createRenderer(for: type)
        try renderer.validateParameters(opacity: opacity)
        
        let manager = OverlayWindowManager.shared
        
        logger.debug("Checking if overlay is already active...")
        let status = manager.getStatus()
        logger.debug("Current status: \(status)")
        
        if status["active"] as? Bool == true {
            logger.debug("Overlay already active, exiting")
            throw WaldoError.overlayAlreadyRunning
        }
        
        logger.debug("Starting overlay manager with type: \(type), luminous: \(luminous)")
        manager.startOverlays(overlayType: type, opacity: opacity, luminous: luminous, logger: logger)
        
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
        abstract: "Stop the transparent overlay watermark."
    )

    @Flag(name: .shortAndLong, help: "Show verbose information during shutdown.")
    var verbose: Bool = false

    @Flag(name: .shortAndLong, help: "Show debugging information for overlay shutdown.")
    var debug: Bool = false

    func run() throws {
        let logger = Logger(verbose: verbose, debug: debug)
        let stopTime = CFAbsoluteTimeGetCurrent()
        
        logger.debug("Starting overlay stop command")
        
        let manager = OverlayWindowManager.shared
        
        logger.debug("Checking current overlay status...")
        let status = manager.getStatus()
        logger.debug("Current status: \(status)")
        
        logger.debug("Attempting to stop local overlay manager...")
        manager.stopOverlays(logger: logger)
        
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
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-f", "waldo overlay start"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.launch()
        
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
        
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let pidStrings = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
        var terminatedCount = 0
        
        for pidString in pidStrings {
            if let pid = Int32(pidString.trimmingCharacters(in: .whitespaces)), pid != currentPID {
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
        abstract: "Show overlay status and statistics."
    )

    @Flag(name: .shortAndLong, help: "Show verbose system and display information.")
    var verbose: Bool = false

    @Flag(name: .shortAndLong, help: "Show debugging information for the status check.")
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
        abstract: "Save a watermark overlay as a PNG for testing."
    )

    @Argument(help: "The file path to save the PNG output.")
    var outputPath: String

    @Option(name: .shortAndLong, help: "The width of the output image in pixels.")
    var width: Int = 1920

    @Option(name: .shortAndLong, help: "The height of the output image in pixels.")
    var height: Int = 1080

    @Option(name: .shortAndLong, help: "The opacity of the overlay, from 1 (nearly transparent) to 255 (fully opaque).")
    var opacity: Int = WatermarkConstants.ALPHA_OPACITY

    @Flag(name: .shortAndLong, help: "Show verbose information during image generation.")
    var verbose: Bool = false

    @Flag(name: .shortAndLong, help: "Show debugging information for image generation.")
    var debug: Bool = false

    func run() throws {
        let logger = Logger(verbose: verbose, debug: debug)
        
        print("Waldo v\(Version.current)")
        print("Saving watermark overlay to: \(outputPath)")
        
        guard opacity >= 1 && opacity <= 255 else {
            throw WaldoError.invalidOpacity(opacity)
        }
        
        let outputURL = URL(fileURLWithPath: outputPath)
        guard outputURL.pathExtension.lowercased() == "png" else {
            throw WaldoError.invalidOutputPath(outputPath)
        }
        
        logger.debug("Creating overlay image with dimensions: \(width)x\(height)")
        logger.debug("Using opacity: \(opacity)/255")
        
        do {
            try saveWatermarkOverlay(to: outputURL, width: width, height: height, opacity: opacity, logger: logger)
            print("✓ Watermark overlay saved successfully")
            
            let systemInfo = SystemInfo.getSystemInfo()
            print("\nWatermark Details:")
            print(".  Username: \(systemInfo["username"] ?? "unknown")")
            print(".  Machine: \(systemInfo["computerName"] ?? "unknown")")
            print(".  Machine UUID: \(systemInfo["machineUUID"] ?? "unknown")")
            print(".  Timestamp: \(SystemInfo.getFormattedTimestamp())")
            
            print("\nTest extraction with:")
            print("  waldo extract \(outputPath) --verbose")
            
        } catch {
            throw WaldoError.failedToSaveOverlay(error)
        }
    }
    
    private func saveWatermarkOverlay(to url: URL, width: Int, height: Int, opacity: Int, logger: Logger) throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        logger.debug("Creating bitmap context...")
        
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
        
        logger.debug("Creating base image for LSB steganography...")
        
        let watermarkData = SystemInfo.getWatermarkDataWithHourlyTimestamp()
        logger.debug("Watermark data: \(watermarkData)")
        
        context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: CGFloat(opacity) / 255.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let baseImage = context.makeImage() else {
            throw NSError(domain: "WaldoError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to create base image"])
        }
        
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
        
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(lsbImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        logger.debug("Skipping visual patterns to preserve LSB data integrity...")
        
        let renderTime = CFAbsoluteTimeGetCurrent() - startTime
        logger.timing("Complex watermark with LSB rendering", duration: renderTime)
        
        guard let cgImage = context.makeImage() else {
            throw NSError(domain: "WaldoError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from context"])
        }
        
        logger.debug("Saving PNG to: \(url.path)")
        
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
    
    private func generateComplexWatermarkPattern(watermarkData: String, opacity: Int, logger: Logger) -> [UInt8] {
        logger.debug("Generating complex watermark pattern...")
        
        let patternSize = WatermarkConstants.PATTERN_SIZE
        let microPattern = generateMicroQRPattern(from: watermarkData)
        let redundantPattern = generateRedundantPattern(from: watermarkData)
        
        var pattern: [UInt8] = []
        for i in 0..<(patternSize * patternSize * 4) {
            let pixelIndex = i / 4
            let channelIndex = i % 4
            
            let microBit = microPattern[pixelIndex % microPattern.count]
            let redundantBit = redundantPattern[pixelIndex % redundantPattern.count]
            
            switch channelIndex {
            case 0: // Red
                let baseValue: UInt8 = UInt8(WatermarkConstants.RGB_BASE)
                if redundantBit == 1 {
                    pattern.append(baseValue + UInt8(WatermarkConstants.RGB_DELTA / 2))
                } else {
                    pattern.append(baseValue)
                }
            case 1: // Green
                let baseValue: UInt8 = UInt8(WatermarkConstants.RGB_BASE)
                if redundantBit == 1 {
                    pattern.append(baseValue + UInt8(WatermarkConstants.RGB_DELTA / 3))
                } else {
                    pattern.append(baseValue)
                }
            case 2: // Blue
                let baseValue: UInt8 = UInt8(WatermarkConstants.RGB_BASE)
                if microBit == 1 {
                    pattern.append(baseValue + UInt8(WatermarkConstants.RGB_DELTA))
                } else {
                    pattern.append(baseValue - UInt8(WatermarkConstants.RGB_DELTA / 2))
                }
            default: // Alpha
                pattern.append(UInt8(opacity))
            }
        }
        
        logger.debug("Generated pattern with \(pattern.count) bytes")
        return pattern
    }
    
    private func generateMicroQRPattern(from data: String) -> [UInt8] {
        let qrSize = WatermarkConstants.QR_VERSION2_SIZE
        var pattern = [UInt8](repeating: 0, count: qrSize * qrSize)
        
        drawFinderPattern(&pattern, size: qrSize, x: 0, y: 0)
        drawFinderPattern(&pattern, size: qrSize, x: qrSize-7, y: 0)
        drawFinderPattern(&pattern, size: qrSize, x: 0, y: qrSize-7)
        drawSeparatorPatterns(&pattern, size: qrSize)
        drawAlignmentPattern(&pattern, size: qrSize, x: 16, y: 16)
        drawTimingPatterns(&pattern, size: qrSize)
        addFormatInformation(&pattern, size: qrSize)
        embedDataWithErrorCorrection(&pattern, size: qrSize, data: data)
        
        return pattern
    }
    
    private func generateRedundantPattern(from data: String) -> [UInt8] {
        let errorCorrectedData = addSimpleErrorCorrection(data)
        let stringData = Data(errorCorrectedData.utf8)
        let bits = stringData.flatMap { byte in
            (0..<8).map { (byte >> $0) & 1 }
        }
        
        let patternSize = WatermarkConstants.PATTERN_SIZE
        var pattern = [UInt8](repeating: 0, count: patternSize * patternSize)
        
        for i in 0..<pattern.count {
            pattern[i] = UInt8(bits[i % bits.count])
        }
        
        return pattern
    }
    
    private func addSimpleErrorCorrection(_ input: String) -> String {
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
        let qrPixelSize = WatermarkConstants.QR_VERSION2_SIZE
        let pixelsPerQRBit: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_PIXELS_PER_MODULE)
        let qrSize: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_PIXEL_SIZE)
        let margin: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_MARGIN)
        let menuBarOffset: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_MENU_BAR_OFFSET)
        
        let qrPattern = generateMicroQRPattern(from: watermarkData)
        if qrPattern.count != qrPixelSize * qrPixelSize {
            logger.debug("Warning: QR pattern size mismatch: \(qrPattern.count) elements, expected \(qrPixelSize * qrPixelSize)")
        }
        
        let corners = [
            CGPoint(x: CGFloat(width) - qrSize - margin, y: CGFloat(height) - menuBarOffset - qrSize),
            CGPoint(x: margin, y: CGFloat(height) - menuBarOffset - qrSize),
            CGPoint(x: CGFloat(width) - qrSize - margin, y: margin),
            CGPoint(x: margin, y: margin)
        ]
        
        logger.debug("Drawing QR codes at \(corners.count) corner positions")
        
        for corner in corners {
            drawQRCode(context: context, at: corner, size: qrSize, pattern: qrPattern, patternSize: qrPixelSize, pixelsPerBit: pixelsPerQRBit, opacity: opacity)
        }
    }
    
    private func drawQRCode(context: CGContext, at position: CGPoint, size: CGFloat, pattern: [UInt8], patternSize: Int, pixelsPerBit: CGFloat, opacity: Int) {
        for y in 0..<patternSize {
            for x in 0..<patternSize {
                let patternIndex = y * patternSize + x
                if patternIndex < pattern.count {
                    let bit = pattern[patternIndex]
                    
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
    
    private func drawFinderPattern(_ pattern: inout [UInt8], size: Int, x: Int, y: Int) {
        let finderSize = 7
        for dy in 0..<finderSize {
            for dx in 0..<finderSize {
                let px = x + dx
                let py = y + dy
                if px < size && py < size {
                    let index = py * size + px
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
        for x in 8..<(size-8) {
            if x != 6 {
                let index = 6 * size + x
                pattern[index] = UInt8(x % 2)
            }
        }
        for y in 8..<(size-8) {
            if y != 6 {
                let index = y * size + 6
                pattern[index] = UInt8(y % 2)
            }
        }
    }
    
    private func drawSeparatorPatterns(_ pattern: inout [UInt8], size: Int) {
        for x in 0..<8 {
            if x < size && 7 < size {
                pattern[7 * size + x] = 0
            }
        }
        for y in 0..<8 {
            if 7 < size && y < size {
                pattern[y * size + 7] = 0
            }
        }
        for x in (size-8)..<size {
            if x >= 0 && x < size && 7 < size {
                pattern[7 * size + x] = 0
            }
        }
        for y in 0..<8 {
            if (size-8) >= 0 && (size-8) < size && y < size {
                pattern[y * size + (size-8)] = 0
            }
        }
        for x in 0..<8 {
            if x < size && (size-8) >= 0 && (size-8) < size {
                pattern[(size-8) * size + x] = 0
            }
        }
        for y in (size-8)..<size {
            if 7 < size && y >= 0 && y < size {
                pattern[y * size + 7] = 0
            }
        }
    }
    
    private func addFormatInformation(_ pattern: inout [UInt8], size: Int) {
        for i in 0..<6 {
            if i < size && 8 < size {
                pattern[8 * size + i] = 0
            }
            if 8 < size && i < size {
                pattern[i * size + 8] = 0
            }
        }
        for i in 7..<9 {
            if i < size && 8 < size {
                pattern[8 * size + i] = 0
            }
            if 8 < size && i < size {
                pattern[i * size + 8] = 0
            }
        }
        for i in 0..<8 {
            if (size-1-i) >= 0 && (size-1-i) < size && 8 < size {
                pattern[8 * size + (size-1-i)] = 0
            }
            if (size-7+i) >= 0 && (size-7+i) < size && 8 < size {
                pattern[(size-7+i) * size + 8] = 0
            }
        }
    }
    
    private func isFormatInformationArea(x: Int, y: Int, size: Int) -> Bool {
        let inHorizontalFormat = (y == 8 && (x < 9 || x >= size-8))
        let inVerticalFormat = (x == 8 && (y < 9 || y >= size-7))
        return inHorizontalFormat || inVerticalFormat
    }
    
    private func embedDataWithErrorCorrection(_ pattern: inout [UInt8], size: Int, data: String) {
        let errorCorrectedData = generateHighErrorCorrectionData(data)
        let stringData = Data(errorCorrectedData.utf8)
        let bits = stringData.flatMap { byte in
            (0..<8).map { (byte >> (7-$0)) & 1 }
        }
        
        var bitIndex = 0
        var up = true
        var col = size - 1
        
        while col > 0 {
            if col == 6 { col -= 1 }
            
            for _ in 0..<size {
                for c in 0..<2 {
                    let x = col - c
                    let y = up ? (size - 1 - (bitIndex / 2) % size) : (bitIndex / 2) % size
                    
                    if x >= 0 && x < size && y >= 0 && y < size {
                        let index = y * size + x
                        
                        let inFinder = isFinderPatternArea(x: x, y: y, size: size)
                        let inAlignment = (x >= 16 && x <= 20 && y >= 16 && y <= 20)
                        let inTiming = (x == 6 || y == 6)
                        let inFormat = isFormatInformationArea(x: x, y: y, size: size)
                        
                        if !inFinder && !inAlignment && !inTiming && !inFormat {
                            if bitIndex < bits.count {
                                pattern[index] = UInt8(bits[bitIndex])
                            } else {
                                pattern[index] = 0
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
        let characterRepeated = input.map { String(repeating: String($0), count: 3) }.joined()
        let blockRepeated = String(repeating: characterRepeated + "|", count: 2)
        let checksum = input.reduce(0) { $0 + Int($1.asciiValue ?? 0) } % 256
        let checksumHex = String(format: "%02X", checksum)
        return blockRepeated + checksumHex
    }
    
    private func drawSubtleCornerQRCodes(context: CGContext, watermarkData: String, width: Int, height: Int, opacity: Int, logger: Logger) {
        let qrPixelSize = WatermarkConstants.QR_VERSION2_SIZE
        let pixelsPerQRBit: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_PIXELS_PER_MODULE)
        let qrSize: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_PIXEL_SIZE)
        let margin: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_MARGIN)
        let menuBarOffset: CGFloat = CGFloat(WatermarkConstants.QR_VERSION2_MENU_BAR_OFFSET)
        
        let qrPattern = generateMicroQRPattern(from: watermarkData)
        
        let corners = [
            CGPoint(x: CGFloat(width) - qrSize - margin, y: CGFloat(height) - menuBarOffset - qrSize),
            CGPoint(x: margin, y: margin)
        ]
        
        logger.debug("Drawing subtle QR codes at \(corners.count) corner positions")
        
        for corner in corners {
            drawSubtleQRCode(context: context, at: corner, size: qrSize, pattern: qrPattern, patternSize: qrPixelSize, pixelsPerBit: pixelsPerQRBit, opacity: opacity)
        }
    }
    
    private func drawSubtleQRCode(context: CGContext, at position: CGPoint, size: CGFloat, pattern: [UInt8], patternSize: Int, pixelsPerBit: CGFloat, opacity: Int) {
        for y in 0..<patternSize {
            for x in 0..<patternSize {
                let patternIndex = y * patternSize + x
                if patternIndex < pattern.count {
                    let bit = pattern[patternIndex]
                    
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
        abstract: "Capture a desktop screenshot with the watermark overlay applied."
    )

    @Argument(help: "The file path to save the PNG screenshot.")
    var outputPath: String

    @Flag(name: .shortAndLong, help: "Show verbose information during capture.")
    var verbose: Bool = false

    @Flag(name: .shortAndLong, help: "Show debugging information for capture.")
    var debug: Bool = false

    func run() throws {
        let logger = Logger(verbose: verbose, debug: debug)
        
        print("Waldo v\(Version.current)")
        print("Capturing desktop with overlay to: \(outputPath)")
        
        let outputURL = URL(fileURLWithPath: outputPath)
        guard outputURL.pathExtension.lowercased() == "png" else {
            throw WaldoError.invalidOutputPath(outputPath)
        }
        
        let manager = OverlayWindowManager.shared
        let status = manager.getStatus()
        
        let isActive = status["active"] as? Bool == true
        let daemonDetected = status["daemonDetected"] as? Bool == true
        
        logger.debug("Overlay status: active=\(isActive), daemon=\(daemonDetected)")
        
        let hasOverlayProcess = checkForOverlayProcess(logger: logger)
        
        guard isActive || daemonDetected || hasOverlayProcess else {
            logger.debug("Status check failed: active=\(isActive), daemon=\(daemonDetected), process=\(hasOverlayProcess)")
            throw WaldoError.noActiveOverlay
        }
        
        if hasOverlayProcess && !isActive {
            logger.debug("Detected overlay process running in daemon mode")
        }
        
        logger.debug("Capturing desktop screenshot with overlay...")
        
        do {
            try captureDesktopWithOverlay(to: outputURL, logger: logger)
            print("✓ Desktop with overlay captured successfully")
            
            let systemInfo = SystemInfo.getSystemInfo()
            print("\nWatermark Details:")
            print(".  Username: \(systemInfo["username"] ?? "unknown")")
            print(".  Machine: \(systemInfo["computerName"] ?? "unknown")")
            print(".  Machine UUID: \(systemInfo["machineUUID"] ?? "unknown")")
            print(".  Timestamp: \(SystemInfo.getFormattedTimestamp())")
            
            print("\nTest extraction with:")
            print("  waldo extract \(outputPath) --verbose")
            
        } catch {
            throw WaldoError.failedToCaptureDesktop(error)
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
        
        guard let displayID = mainScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            throw NSError(domain: "WaldoError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not get display ID"])
        }
        
        let cgDisplayID = CGDirectDisplayID(displayID.uint32Value)
        
        logger.debug("Capturing screen with CGDisplayCreateImage...")
        
        guard let image = CGDisplayCreateImage(cgDisplayID) else {
            throw NSError(domain: "WaldoError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to capture screen"])
        }
        
        let captureTime = CFAbsoluteTimeGetCurrent() - startTime
        logger.timing("Screen capture", duration: captureTime)
        
        logger.debug("Saving captured image to: \(url.path)")
        
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

struct OverlaySampleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "overlay_sample",
        abstract: "Display a tiled wireframe beagle overlay for testing."
    )

    @Option(name: .shortAndLong, help: "The size of each repeating beagle tile in pixels.")
    var tileSize: Int = 150

    @Option(name: .shortAndLong, help: "The line width for the wireframe beagle drawing.")
    var lineWidth: Int = 3

    @Option(name: .shortAndLong, help: "The opacity of the beagle overlay as a percentage (0.1 to 100).")
    var opacity: Double = 5.0

    @Flag(name: .shortAndLong, help: "Show verbose information during startup.")
    var verbose: Bool = false

    @Flag(name: .shortAndLong, help: "Show debugging information for startup.")
    var debug: Bool = false

    func run() throws {
        let logger = Logger(verbose: verbose, debug: debug)
        
        print("Waldo v\(Version.current)")
        print("Starting wireframe beagle overlay sample...")
        
        logger.debug("Creating beagle overlay with tile size: \(tileSize), line width: \(lineWidth), opacity: \(opacity)%")
        
        guard tileSize >= 50 && tileSize <= 500 else {
            throw WaldoError.invalidTileSize(tileSize)
        }
        
        guard lineWidth >= 1 && lineWidth <= 10 else {
            throw WaldoError.invalidLineWidth(lineWidth)
        }
        
        guard opacity >= 0.1 && opacity <= 100.0 else {
            throw WaldoError.invalidOpacityPercentage(opacity)
        }
        
        let manager = OverlayWindowManager.shared
        let status = manager.getStatus()
        
        if status["active"] as? Bool == true {
            throw WaldoError.overlayAlreadyRunning
        }
        
        logger.debug("Starting beagle overlay...")
        
        let userName = NSUserName()
        
        do {
            try startBeagleOverlay(tileSize: tileSize, lineWidth: lineWidth, opacity: opacity, userName: userName, logger: logger)
            print("✓ Wireframe beagle overlay started successfully")
            print("✓ User: \(userName)")
            print("✓ Opacity: \(opacity)% visibility")
            print("Press Ctrl+C to stop the overlay")
            
            RunLoop.main.run()
        } catch {
            logger.debug("Failed to start beagle overlay: \(error)")
            throw WaldoError.failedToStartBeagleOverlay(error)
        }
    }
    
    private func startBeagleOverlay(tileSize: Int, lineWidth: Int, opacity: Double, userName: String, logger: Logger) throws {
        let screens = NSScreen.screens
        var overlayWindows: [NSWindow] = []
        
        for screen in screens {
            logger.debug("Creating beagle overlay for screen: \(screen.frame)")
            
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.overlayWindow)))
            window.isOpaque = false
            window.backgroundColor = NSColor.clear
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            
            let beagleView = BeagleOverlayView(frame: window.contentView!.bounds, tileSize: tileSize, lineWidth: lineWidth, opacity: opacity, userName: userName)
            window.contentView = beagleView
            
            window.makeKeyAndOrderFront(nil)
            overlayWindows.append(window)
        }
        
        logger.debug("Created \(overlayWindows.count) beagle overlay windows")
        
        OverlayWindowManager.shared.setBeagleWindows(overlayWindows)
    }
}