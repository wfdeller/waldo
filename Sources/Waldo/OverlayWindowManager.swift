import Cocoa
import Foundation

class OverlayWindowManager: NSObject {
    private enum OverlayState {
        case active
        case inactive
    }

    private var overlayWindows: [NSScreen: NSWindow] = [:]
    private var watermarkViews: [NSScreen: WatermarkOverlayView] = [:]
    private var overlayViews: [NSScreen: NSView] = [:]
    private var beagleWindows: [NSWindow] = []
    private var refreshTimer: Timer?
    private var state: OverlayState = .inactive
    private var currentOpacity: Int = WatermarkConstants.ALPHA_OPACITY
    private var currentOverlayType: OverlayType = .hybrid
    private var renderer: OverlayRenderer?
    private var luminousEnabled: Bool = false

    static let shared = OverlayWindowManager()

    private override init() {
        super.init()
        setupScreenChangeNotifications()
    }

    deinit {
        stopOverlays()
        NotificationCenter.default.removeObserver(self)
    }

    func startOverlays(opacity: Int = WatermarkConstants.ALPHA_OPACITY, logger: Logger = Logger()) {
        // Backward compatibility method - use hybrid overlay type
        startOverlays(overlayType: .hybrid, opacity: opacity, logger: logger)
    }
    
    func startOverlays(overlayType: OverlayType, opacity: Int = WatermarkConstants.ALPHA_OPACITY, luminous: Bool = false, logger: Logger = Logger()) {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard state == .inactive else {
            logger.debug("Overlay already active, skipping start")
            return
        }

        logger.debug("Starting overlay system with type: \(overlayType), opacity: \(opacity)/255, luminous: \(luminous)")
        logger.debug("Available screens: \(NSScreen.screens.count)")

        for (index, screen) in NSScreen.screens.enumerated() {
            let frame = screen.frame
            let scale = screen.backingScaleFactor
            logger.debug("Screen \(index): \(Int(frame.width))x\(Int(frame.height)) @\(scale)x scale")
        }

        currentOpacity = opacity
        currentOverlayType = overlayType
        luminousEnabled = luminous
        renderer = OverlayRendererFactory.createRenderer(for: overlayType)
        state = .active
        
        createOverlayWindows(opacity: opacity, luminous: luminous, logger: logger)
        startRefreshTimer()

        let startupTime = CFAbsoluteTimeGetCurrent() - startTime
        logger.timing("Overlay startup", duration: startupTime)

        print("✓ Desktop overlay watermarking started on \(NSScreen.screens.count) display(s)")
        print("✓ Overlay type: \(overlayType.rawValue)")
        if luminous {
            print("✓ Luminous enhancement: enabled")
        }
        print("✓ Overlay opacity: \(opacity)/255 (≈\(Int(round(Double(opacity) / 255.0 * 100)))%)")

        logger.debug("Overlay system started successfully")
        logger.debug("Active windows: \(overlayWindows.count)")
        logger.debug("Active overlay views: \(overlayViews.count)")
    }

    func stopOverlays(logger: Logger = Logger()) {
        let stopTime = CFAbsoluteTimeGetCurrent()

        guard state == .active else {
            logger.debug("Overlay not active, skipping stop")
            return
        }

        logger.debug("Stopping overlay system")
        logger.debug("Windows to remove: \(overlayWindows.count)")
        logger.debug("Views to clean up: \(watermarkViews.count)")

        state = .inactive
        stopRefreshTimer()
        removeAllOverlayWindows()

        let shutdownTime = CFAbsoluteTimeGetCurrent() - stopTime
        logger.timing("Overlay shutdown", duration: shutdownTime)

        print("✓ Desktop overlay watermarking stopped")
        logger.debug("Overlay system stopped successfully")
    }

    func refreshWatermarks() {
        guard state == .active else { return }

        let newWatermarkData = SystemInfo.getWatermarkDataWithHourlyTimestamp()

        for (_, view) in watermarkViews {
            view.updateWatermarkData(newWatermarkData, opacity: currentOpacity)
        }

        print("✓ Watermark overlay refreshed at \(SystemInfo.getFormattedTimestamp())")
    }

    func getStatus() -> [String: Any] {
        let actuallyActive = state == .active && !overlayWindows.isEmpty
        let daemonRunning = isWaldoDaemonRunning()

        var status: [String: Any] = [
            "active": actuallyActive || daemonRunning,
            "screenCount": NSScreen.screens.count,
            "overlayWindowsCount": overlayWindows.count,
            "currentWatermark": SystemInfo.getWatermarkDataWithHourlyTimestamp(),
            "lastRefresh": SystemInfo.getFormattedTimestamp(),
            "daemonDetected": daemonRunning
        ]

        if let mainScreen = NSScreen.main {
            let frame = mainScreen.frame
            let scale = mainScreen.backingScaleFactor
            status["screenLogicalSize"] = "\(Int(frame.width))x\(Int(frame.height))"
            status["screenLogicalResolution"] = "\(Int(frame.width * scale))x\(Int(frame.height * scale))"
            status["backingScaleFactor"] = scale
        }

        return status
    }

    private func createOverlayWindows(opacity: Int = WatermarkConstants.ALPHA_OPACITY, luminous: Bool = false, logger: Logger = Logger()) {
        logger.debug("Creating overlay windows for \(NSScreen.screens.count) screens")
        removeAllOverlayWindows()

        for (index, screen) in NSScreen.screens.enumerated() {
            let windowStartTime = CFAbsoluteTimeGetCurrent()
            createOverlayWindow(for: screen, opacity: opacity, luminous: luminous)
            let windowTime = CFAbsoluteTimeGetCurrent() - windowStartTime
            logger.debug("Created window for screen \(index) in \(String(format: "%.3f", windowTime))s")
        }

        logger.debug("Finished creating \(overlayWindows.count) overlay windows")
    }

    private func createOverlayWindow(for screen: NSScreen, opacity: Int = WatermarkConstants.ALPHA_OPACITY, luminous: Bool = false) {
        let frame = screen.frame
        let visibleFrame = screen.visibleFrame
        let backingScaleFactor = screen.backingScaleFactor

        let overlayFrame = frame

        let window = NSWindow(
            contentRect: overlayFrame,
            styleMask: [],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = WatermarkConstants.overlayWindowLevel
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        window.setFrame(overlayFrame, display: true)

        // Create overlay view using renderer system
        let overlayView = createOverlayView(frame: NSRect(origin: .zero, size: overlayFrame.size), opacity: opacity, luminous: luminous)
        
        window.contentView = overlayView
        window.orderFront(nil)

        overlayWindows[screen] = window
        overlayViews[screen] = overlayView
        
        // Maintain backward compatibility for hybrid overlays that use WatermarkOverlayView
        if currentOverlayType == .hybrid,
           let watermarkView = overlayView as? WatermarkOverlayView {
            watermarkViews[screen] = watermarkView
        }

        var nativeWidth = Int(frame.width)
        var nativeHeight = Int(frame.height)

        if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            let cgDisplayID = CGDirectDisplayID(displayID.uint32Value)

            if let modes = CGDisplayCopyAllDisplayModes(cgDisplayID, nil) {
                let modeCount = CFArrayGetCount(modes)
                var maxWidth = 0
                var maxHeight = 0

                for i in 0..<modeCount {
                    if let mode = CFArrayGetValueAtIndex(modes, i) {
                        let displayMode = Unmanaged<CGDisplayMode>.fromOpaque(mode).takeUnretainedValue()
                        let width = displayMode.width
                        let height = displayMode.height

                        if width > maxWidth {
                            maxWidth = width
                            maxHeight = height
                        }
                    }
                }

                if maxWidth > 0 && maxHeight > 0 {
                    nativeWidth = maxWidth
                    nativeHeight = maxHeight
                }
            }
        }

        print("Created overlay window for screen:")
        print(".  Frame: \(Int(frame.width))x\(Int(frame.height)) at (\(Int(frame.origin.x)), \(Int(frame.origin.y)))")
        print(".  Visible: \(Int(visibleFrame.width))x\(Int(visibleFrame.height)) at (\(Int(visibleFrame.origin.x)), \(Int(visibleFrame.origin.y)))")
        print(".  Backing Scale: \(backingScaleFactor)x")
        print(".  Logical Resolution: \(Int(frame.width * backingScaleFactor))x\(Int(frame.height * backingScaleFactor))")
        print(".  Native Resolution: \(nativeWidth)x\(nativeHeight)")
        print(".  Overlay covers logical resolution (watermarks will scale with display settings)")
    }
    
    private func createOverlayView(frame: NSRect, opacity: Int, luminous: Bool = false) -> NSView {
        let logger = Logger()
        
        if let renderer = renderer {
            if let view = renderer.createOverlayView(frame: frame, opacity: opacity, luminous: luminous, logger: logger) {
                return view
            }
        }
        
        // Fallback to hybrid renderer
        logger.debug("No renderer available, falling back to hybrid renderer")
        let hybridRenderer = HybridOverlayRenderer()
        return hybridRenderer.createOverlayView(frame: frame, opacity: opacity, luminous: luminous, logger: logger) ?? NSView(frame: frame)
    }

    private func removeAllOverlayWindows() {
        for (_, window) in overlayWindows {
            window.close()
        }
        overlayWindows.removeAll()
        watermarkViews.removeAll()
        overlayViews.removeAll()
    }

    private func startRefreshTimer() {
        stopRefreshTimer()

        let calendar = Calendar.current
        let now = Date()
        let nextHour = calendar.nextDate(
            after: now,
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)

        let timeUntilNextHour = nextHour.timeIntervalSince(now)

        DispatchQueue.main.asyncAfter(deadline: .now() + timeUntilNextHour) { [weak self] in
            self?.refreshWatermarks()

            self?.refreshTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
                self?.refreshWatermarks()
            }
        }

        print(".  Next watermark refresh scheduled for: \(nextHour)")
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func setupScreenChangeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        guard state == .active else { return }

        print("Screen configuration changed, updating overlays...")
        // Update renderer to match current overlay type
        renderer = OverlayRendererFactory.createRenderer(for: currentOverlayType)
        createOverlayWindows(opacity: currentOpacity, luminous: luminousEnabled, logger: Logger(verbose: true))
    }

    private func isWaldoDaemonRunning() -> Bool {
        guard let processList = getRunningProcesses() else {
            return false
        }
        return parseProcessListForWaldoDaemon(processList)
    }

    private func getRunningProcesses() -> String? {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["ax", "-o", "pid,command"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        let semaphore = DispatchSemaphore(value: 0)
        var taskCompleted = false

        DispatchQueue.global(qos: .utility).async {
            task.launch()
            task.waitUntilExit()
            taskCompleted = true
            semaphore.signal()
        }

        let timeout = DispatchTime.now() + .seconds(3)
        if semaphore.wait(timeout: timeout) == .timedOut {
            task.terminate()
            return nil
        }

        guard taskCompleted else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func parseProcessListForWaldoDaemon(_ output: String) -> Bool {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            if line.contains("waldo") && line.contains("overlay start") {
                let components = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
                if let pidString = components.first, let pid = Int32(pidString), pid != currentPID {
                    return true
                }
            }
        }
        return false
    }

    func setBeagleWindows(_ windows: [NSWindow]) {
        beagleWindows = windows
    }

    func stopBeagleOverlay() {
        for window in beagleWindows {
            window.orderOut(nil)
        }
        beagleWindows.removeAll()
    }
}
