import ArgumentParser
import Foundation
import CoreGraphics
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
        
        if let result = PhotoProcessor.extractWatermarkFromPhoto(at: photoURL, threshold: threshold, verbose: verbose, debug: debug, enableScreenDetection: !noScreenDetection) {
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
    
    @Flag(name: .shortAndLong, help: "Run in background (daemon mode)")
    var daemon: Bool = false
    
    func run() throws {
        print("Waldo v\(Version.current)")
        print("Watermark pattern size: \(WatermarkConstants.PATTERN_SIZE) pixels")
        
        // Validate opacity parameter
        guard opacity >= 1 && opacity <= 255 else {
            print("Error: Opacity must be between 1 and 255 (provided: \(opacity))")
            throw ExitCode.failure
        }
        
        let manager = OverlayWindowManager.shared
        
        if manager.getStatus()["active"] as? Bool == true {
            print("Error: Overlay is already running. Use 'waldo overlay stop' first.")
            throw ExitCode.failure
        }
        
        manager.startOverlays(opacity: opacity)
        
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
    
    func run() throws {
        let manager = OverlayWindowManager.shared
        
        // First try to stop local overlays (if running in same process)
        manager.stopOverlays()
        
        // Check for and terminate any waldo overlay start processes
        // (whether daemon or interactive) - this bypasses getStatus() issues
        let terminatedCount = terminateOverlayProcesses()
        
        if terminatedCount == 0 {
            print("No overlay processes are currently running.")
        }
    }
    
    private func terminateOverlayProcesses() -> Int {
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
    
    func run() throws {
        print("Waldo v\(Version.current)")
        
        let manager = OverlayWindowManager.shared
        let status = manager.getStatus()
        
        print("Desktop Overlay Status:")
        let isActive = status["active"] as? Bool == true
        let isDaemonDetected = status["daemonDetected"] as? Bool == true
        
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