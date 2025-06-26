import ArgumentParser
import Foundation
import CoreGraphics
import Cocoa

@main
struct Waldo: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "waldo",
        abstract: "Waldo - A steganographic desktop identification system for macOS",
        subcommands: [EmbedCommand.self, ExtractCommand.self, SetupCommand.self, ListUsersCommand.self, OverlayCommand.self],
        defaultSubcommand: OverlayCommand.self
    )
}

struct EmbedCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "embed",
        abstract: "Capture desktop screenshot and embed steganographic watermark"
    )
    
    @Option(name: .shortAndLong, help: "User ID for watermark")
    var userID: String
    
    @Option(name: .shortAndLong, help: "Custom watermark text")
    var watermark: String = ""
    
    @Option(name: .shortAndLong, help: "Output file path")
    var output: String?
    
    @Flag(name: .shortAndLong, help: "Capture all displays")
    var allDisplays: Bool = false
    
    func run() throws {
        guard ScreenCapture.requestScreenRecordingPermission() else {
            print("Error: Screen recording permission required. Please grant permission in System Preferences > Security & Privacy > Privacy > Screen Recording")
            throw ExitCode.failure
        }
        
        // Auto-create user event if needed
        APIClient.shared.logEvent(
            eventType: "user_create",
            watermarkData: SystemInfo.getWatermarkDataWithHourlyTimestamp(),
            metadata: ["autoCreated": true, "triggeredBy": "embed"]
        )
        
        if allDisplays {
            let images = ScreenCapture.captureAllDisplays()
            for (index, image) in images.enumerated() {
                processImage(image, userID: userID, watermark: watermark, suffix: "_display\(index)")
            }
        } else {
            guard let image = ScreenCapture.captureMainDisplay() else {
                print("Error: Failed to capture main display")
                throw ExitCode.failure
            }
            processImage(image, userID: userID, watermark: watermark)
        }
    }
    
    private func processImage(_ image: CGImage, userID: String, watermark: String, suffix: String = "") {
        let finalWatermark = watermark.isEmpty ? SystemInfo.getWatermarkDataWithHourlyTimestamp() : watermark
        let fullWatermark = "\(userID):\(finalWatermark):\(Date().timeIntervalSince1970)"
        
        guard let watermarkedImage = RobustWatermarkEngine.embedPhotoResistantWatermark(in: image, data: fullWatermark) else {
            print("Error: Failed to embed watermark")
            return
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = output ?? "watermarked_desktop_\(timestamp)\(suffix).png"
        let outputURL = URL(fileURLWithPath: filename)
        
        do {
            try ScreenCapture.saveImageAsPNG(watermarkedImage, to: outputURL)
            print("✓ Watermarked screenshot saved to: \(outputURL.path)")
            
            // Log embed event to API
            APIClient.shared.logEvent(
                eventType: "embed",
                watermarkData: SystemInfo.getWatermarkDataWithHourlyTimestamp(),
                metadata: [
                    "imagePath": outputURL.path,
                    "watermarkText": finalWatermark,
                    "suffix": suffix
                ]
            )
        } catch {
            print("Error saving image: \(error)")
        }
    }
}

struct ExtractCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extract watermark from a photo"
    )
    
    @Argument(help: "Path to photo file")
    var photoPath: String
    
    @Flag(name: .shortAndLong, help: "Show detailed information")
    var verbose: Bool = false
    
    func run() throws {
        let photoURL = URL(fileURLWithPath: photoPath)
        
        guard FileManager.default.fileExists(atPath: photoPath) else {
            print("Error: File not found at \(photoPath)")
            throw ExitCode.failure
        }
        
        guard PhotoProcessor.isImageFile(photoURL) else {
            print("Error: Not a valid image file")
            throw ExitCode.failure
        }
        
        if let result = PhotoProcessor.extractWatermarkFromPhoto(at: photoURL) {
            print("🔍 Watermark detected!")
            
            // The robust extraction already provides parsed components
            print("Username: \(result.userID)")
            
            // Try to parse the watermark portion for additional details
            if let parsed = SystemInfo.parseWatermarkData(result.watermark) {
                print("Computer: \(parsed.computerName ?? "unknown")")
                print("Machine UUID: \(parsed.machineUUID ?? "unknown")")
            } else {
                // For robust extraction, the watermark might be in a different format
                let components = result.watermark.components(separatedBy: ":")
                if components.count >= 2 {
                    print("Computer: \(components[0])")
                    if components.count >= 3 {
                        print("Machine UUID: \(components[1])")
                    }
                } else {
                    print("Computer: \(result.watermark)")
                    print("Machine UUID: unknown")
                }
            }
            
            if verbose {
                let date = Date(timeIntervalSince1970: result.timestamp)
                print("Timestamp: \(date)")
            }
            
            // Log extraction to API
            APIClient.shared.logExtraction(
                watermarkData: "\(result.userID):\(result.watermark):\(Int(result.timestamp))",
                photoPath: photoPath,
                confidence: 1.0
            )
        } else {
            print("❌ No watermark detected in the image")
            throw ExitCode.failure
        }
    }
}

struct SetupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setup",
        abstract: "Set up a new user for watermarking"
    )
    
    @Option(name: .shortAndLong, help: "User ID")
    var userID: String
    
    @Option(name: .shortAndLong, help: "User's full name")
    var name: String
    
    @Option(name: .shortAndLong, help: "User's email address")
    var email: String?
    
    func run() throws {
        print("✓ User setup completed")
        print("Name: \(name)")
        if let email = email {
            print("Email: \(email)")
        }
        print("Note: User details will be automatically logged when overlay starts or embed is used")
        
        // Log user creation to API
        APIClient.shared.logEvent(
            eventType: "user_create",
            watermarkData: SystemInfo.getWatermarkDataWithHourlyTimestamp(),
            metadata: [
                "name": name,
                "email": email ?? "",
                "manualSetup": true
            ]
        )
    }
}

struct ListUsersCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "users",
        abstract: "Show current system user and recent activity"
    )
    
    func run() throws {
        let systemInfo = SystemInfo.getSystemInfo()
        
        print("Current System User:")
        print("===================")
        print("Username: \(systemInfo["username"] ?? "unknown")")
        print("Full Name: \(systemInfo["fullName"] ?? "unknown")")
        print("Computer: \(systemInfo["computerName"] ?? "unknown")")
        print("Machine UUID: \(systemInfo["machineUUID"] ?? "unknown")")
        print("OS Version: \(systemInfo["osVersion"] ?? "unknown")")
        
        print("\nNote: All user activity is logged to the centralized API.")
        print("Use the API endpoints to query detailed user statistics and history.")
        print("Example: GET /api/events/user/\(systemInfo["username"] ?? "username")")
    }
}

struct OverlayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "overlay",
        abstract: "Manage transparent desktop overlay watermarking",
        subcommands: [StartOverlayCommand.self, StopOverlayCommand.self, StatusOverlayCommand.self, DebugScreenCommand.self]
    )
}

struct DebugScreenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "debug-screen",
        abstract: "Debug screen resolution and display information"
    )
    
    func run() throws {
        print("Display Configuration Debug")
        print("==========================")
        
        let screens = NSScreen.screens
        print("Number of screens: \(screens.count)")
        
        for (index, screen) in screens.enumerated() {
            print("\nScreen \(index):")
            print("  Frame: \(screen.frame)")
            print("  Visible Frame: \(screen.visibleFrame)")
            print("  Backing Scale Factor: \(screen.backingScaleFactor)")
            
            let frame = screen.frame
            let actualWidth = Int(frame.width * screen.backingScaleFactor)
            let actualHeight = Int(frame.height * screen.backingScaleFactor)
            print("  Logical Size: \(Int(frame.width)) x \(Int(frame.height))")
            print("  Physical Size: \(actualWidth) x \(actualHeight)")
            
            let deviceDescription = screen.deviceDescription
            print("  Device Description:")
            for (key, value) in deviceDescription {
                print("    \(key.rawValue): \(value)")
            }
            
            // Try to get more display info using Core Graphics
            if let displayID = deviceDescription[.init("NSScreenNumber")] as? NSNumber {
                let cgDisplayID = CGDirectDisplayID(displayID.uint32Value)
                let pixelWidth = CGDisplayPixelsWide(cgDisplayID)
                let pixelHeight = CGDisplayPixelsHigh(cgDisplayID)
                print("  Core Graphics Pixel Size: \(pixelWidth) x \(pixelHeight)")
                
                let displayBounds = CGDisplayBounds(cgDisplayID)
                print("  Core Graphics Bounds: \(displayBounds)")
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
    
    @Flag(name: .shortAndLong, help: "Run in background (daemon mode)")
    var daemon: Bool = false
    
    func run() throws {
        guard ScreenCapture.requestScreenRecordingPermission() else {
            print("Error: Screen recording permission required. Please grant permission in System Preferences > Security & Privacy > Privacy > Screen Recording")
            throw ExitCode.failure
        }
        
        let manager = OverlayWindowManager.shared
        
        if manager.getStatus()["active"] as? Bool == true {
            print("Error: Overlay is already running. Use 'waldo overlay stop' first.")
            throw ExitCode.failure
        }
        
        manager.startOverlays()
        
        let runLoop = RunLoop.current
        let distantFuture = Date.distantFuture
        
        signal(SIGINT) { _ in
            print("\n🛑 Received interrupt signal, stopping overlays...")
            OverlayWindowManager.shared.stopOverlays()
            Darwin.exit(0)
        }
        
        signal(SIGTERM) { _ in
            print("\n🛑 Received termination signal, stopping overlays...")
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
    
    func run() throws {
        let manager = OverlayWindowManager.shared
        
        if manager.getStatus()["active"] as? Bool == false {
            print("No overlay is currently running.")
            return
        }
        
        manager.stopOverlays()
    }
}

struct StatusOverlayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show overlay status and statistics"
    )
    
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false
    
    func run() throws {
        let manager = OverlayWindowManager.shared
        let status = manager.getStatus()
        let apiStatus = APIClient.shared.getQueueStatus()
        
        print("Desktop Overlay Status")
        print("=====================")
        let isActive = status["active"] as? Bool == true
        let isDaemonDetected = status["daemonDetected"] as? Bool == true
        
        print("Active: \(isActive ? "✓ Yes" : "✗ No")")
        print("Screens: \(status["screenCount"] ?? 0)")
        
        if isDaemonDetected {
            print("Overlay Windows: \(status["screenCount"] ?? 0) (estimated - running in separate process)")
        } else {
            print("Overlay Windows: \(status["overlayWindowsCount"] ?? 0)")
        }
        
        // Display resolution info
        if let logicalSize = status["screenLogicalSize"] as? String,
           let logicalRes = status["screenLogicalResolution"] as? String,
           let scale = status["backingScaleFactor"] as? CGFloat {
            print("Screen (Logical): \(logicalSize)")
            print("Overlay Coverage: \(logicalRes)")
            print("Retina Scale: \(scale)x")
        }
        
        if let watermark = status["currentWatermark"] as? String {
            let systemInfo = SystemInfo.parseWatermarkData(watermark)
            print("Current User: \(systemInfo?.username ?? "unknown")")
            print("Machine: \(systemInfo?.computerName ?? "unknown")")
            if let timestamp = systemInfo?.timestamp {
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                print("Last Refresh: \(date)")
            }
        }
        
        if verbose {
            print("\nAPI Client Status")
            print("================")
            print("Base URL: \(apiStatus["baseURL"] ?? "unknown")")
            print("Has API Key: \(apiStatus["hasApiKey"] as? Bool == true ? "✓ Yes" : "✗ No")")
            print("Queued Events: \(apiStatus["queuedEvents"] ?? 0)")
            
            print("\nSystem Information")
            print("==================")
            let sysInfo = SystemInfo.getSystemInfo()
            for (key, value) in sysInfo {
                print("\(key): \(value)")
            }
        }
    }
}