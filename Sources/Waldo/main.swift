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
    
    @Flag(name: .shortAndLong, help: "Show detailed information")
    var verbose: Bool = false
    
    func run() throws {
        print("Waldo v\(Version.current)")
        
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
    
    @Flag(name: .shortAndLong, help: "Run in background (daemon mode)")
    var daemon: Bool = false
    
    func run() throws {
        print("Waldo v\(Version.current)")
        
        let manager = OverlayWindowManager.shared
        
        if manager.getStatus()["active"] as? Bool == true {
            print("Error: Overlay is already running. Use 'waldo overlay stop' first.")
            throw ExitCode.failure
        }
        
        manager.startOverlays()
        
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