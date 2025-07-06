using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Forms;
using System.Windows.Threading;

namespace Waldo.Windows
{
    public class OverlayManager
    {
        private static OverlayManager? _instance;
        private readonly List<OverlayWindow> _overlayWindows = new();
        private readonly object _lock = new();
        private Thread? _overlayThread;
        private volatile bool _isRunning = false;
        
        public static OverlayManager Instance => _instance ??= new OverlayManager();
        
        public bool IsRunning => _isRunning;
        
        public bool StartOverlay(string overlayType = "hybrid", double opacity = 0.4, bool luminousEnabled = false, bool verbose = false)
        {
            lock (_lock)
            {
                if (_isRunning)
                {
                    if (verbose) Console.WriteLine("Overlay is already running");
                    return false;
                }
                
                try
                {
                    _overlayThread = new Thread(() => RunOverlayThread(overlayType, opacity, luminousEnabled, verbose))
                    {
                        IsBackground = false,
                        Name = "WaldoOverlayThread"
                    };
                    
                    _overlayThread.SetApartmentState(ApartmentState.STA);
                    _overlayThread.Start();
                    
                    // Wait for overlay to start
                    var timeout = DateTime.Now.AddSeconds(10);
                    while (!_isRunning && DateTime.Now < timeout)
                    {
                        Thread.Sleep(100);
                    }
                    
                    if (verbose) Console.WriteLine($"Overlay started successfully with type: {overlayType}");
                    return _isRunning;
                }
                catch (Exception ex)
                {
                    if (verbose) Console.WriteLine($"Error starting overlay: {ex.Message}");
                    return false;
                }
            }
        }
        
        public bool StopOverlay(bool verbose = false)
        {
            lock (_lock)
            {
                if (!_isRunning)
                {
                    if (verbose) Console.WriteLine("No overlay is currently running");
                    return false;
                }
                
                try
                {
                    _isRunning = false;
                    
                    // Close all overlay windows
                    foreach (var window in _overlayWindows.ToList())
                    {
                        window.Dispatcher.Invoke(() =>
                        {
                            window.Close();
                        });
                    }
                    
                    _overlayWindows.Clear();
                    
                    if (_overlayThread != null && _overlayThread.IsAlive)
                    {
                        if (!_overlayThread.Join(5000)) // Wait up to 5 seconds
                        {
                            _overlayThread.Abort();
                        }
                    }
                    
                    if (verbose) Console.WriteLine("Overlay stopped successfully");
                    return true;
                }
                catch (Exception ex)
                {
                    if (verbose) Console.WriteLine($"Error stopping overlay: {ex.Message}");
                    return false;
                }
            }
        }
        
        public string GetOverlayStatus()
        {
            lock (_lock)
            {
                if (!_isRunning)
                {
                    return "No overlay is currently running";
                }
                
                var windowCount = _overlayWindows.Count;
                var screens = Screen.AllScreens;
                
                return $"Overlay is running on {windowCount} display(s) out of {screens.Length} available screen(s)";
            }
        }
        
        public Dictionary<string, object> GetDetailedStatus()
        {
            lock (_lock)
            {
                var screens = Screen.AllScreens;
                var systemInfo = SystemInfo.GetSystemInfo();
                
                return new Dictionary<string, object>
                {
                    ["isRunning"] = _isRunning,
                    ["windowCount"] = _overlayWindows.Count,
                    ["totalScreens"] = screens.Length,
                    ["primaryScreen"] = new
                    {
                        bounds = Screen.PrimaryScreen.Bounds,
                        workingArea = Screen.PrimaryScreen.WorkingArea,
                        primary = Screen.PrimaryScreen.Primary
                    },
                    ["allScreens"] = screens.Select(s => new
                    {
                        bounds = s.Bounds,
                        workingArea = s.WorkingArea,
                        primary = s.Primary,
                        deviceName = s.DeviceName
                    }).ToArray(),
                    ["systemInfo"] = systemInfo,
                    ["timestamp"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                };
            }
        }
        
        private void RunOverlayThread(string overlayType, double opacity, bool luminousEnabled, bool verbose)
        {
            try
            {
                var app = new System.Windows.Application();
                app.ShutdownMode = ShutdownMode.OnExplicitShutdown;
                
                // Create overlay windows for each screen
                var screens = Screen.AllScreens;
                
                foreach (var screen in screens)
                {
                    app.Dispatcher.Invoke(() =>
                    {
                        var window = new OverlayWindow(overlayType, opacity, luminousEnabled);
                        
                        // Position window on specific screen
                        window.Left = screen.Bounds.Left;
                        window.Top = screen.Bounds.Top;
                        window.Width = screen.Bounds.Width;
                        window.Height = screen.Bounds.Height;
                        
                        window.Show();
                        _overlayWindows.Add(window);
                        
                        if (verbose) Console.WriteLine($"Created overlay window on screen {screen.DeviceName} at {screen.Bounds}");
                    });
                }
                
                _isRunning = true;
                
                // Handle window closing
                app.Dispatcher.Invoke(() =>
                {
                    foreach (var window in _overlayWindows)
                    {
                        window.Closed += (s, e) =>
                        {
                            if (_overlayWindows.All(w => !w.IsVisible))
                            {
                                StopOverlay(verbose);
                            }
                        };
                    }
                });
                
                // Run the WPF application
                app.Run();
            }
            catch (Exception ex)
            {
                if (verbose) Console.WriteLine($"Error in overlay thread: {ex.Message}");
            }
            finally
            {
                _isRunning = false;
            }
        }
        
        public bool SaveOverlay(string filePath, int width = 1920, int height = 1080, string overlayType = "hybrid", double opacity = 0.4, bool verbose = false)
        {
            try
            {
                var watermarkData = SystemInfo.GetWatermarkDataWithHourlyTimestamp();
                
                using var image = new SixLabors.ImageSharp.Image<SixLabors.ImageSharp.PixelFormats.Rgba32>(width, height);
                
                // Create overlay based on type
                switch (overlayType.ToLower())
                {
                    case "steganography":
                        var watermarkedImage = Core.SteganographyEngine.EmbedWatermark(image, watermarkData, SystemInfo.GetUsername());
                        if (watermarkedImage != null)
                        {
                            watermarkedImage.SaveAsPng(filePath);
                            if (verbose) Console.WriteLine($"Saved steganography overlay to {filePath}");
                            return true;
                        }
                        break;
                        
                    default:
                        // For other overlay types, create a basic watermarked image
                        var basicWatermarked = Core.SteganographyEngine.EmbedWatermark(image, watermarkData, SystemInfo.GetUsername());
                        if (basicWatermarked != null)
                        {
                            basicWatermarked.SaveAsPng(filePath);
                            if (verbose) Console.WriteLine($"Saved {overlayType} overlay to {filePath}");
                            return true;
                        }
                        break;
                }
                
                return false;
            }
            catch (Exception ex)
            {
                if (verbose) Console.WriteLine($"Error saving overlay: {ex.Message}");
                return false;
            }
        }
    }
}