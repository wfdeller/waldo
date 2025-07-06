using System;
using System.CommandLine;
using System.CommandLine.Invocation;
using System.IO;
using System.Threading.Tasks;
using Waldo.Core;
using Waldo.Windows;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;

namespace Waldo.CLI
{
    public class Program
    {
        public static async Task<int> Main(string[] args)
        {
            var rootCommand = new RootCommand("Waldo - A steganographic desktop identification system for Windows.")
            {
                CreateExtractCommand(),
                CreateOverlayCommand()
            };

            return await rootCommand.InvokeAsync(args);
        }

        private static Command CreateExtractCommand()
        {
            var extractCommand = new Command("extract", "Extract a watermark from a photo.");

            var photoPathArg = new Argument<string>("photoPath", "Path to the photo file to extract a watermark from.");
            var thresholdOption = new Option<double>(new[] { "--threshold", "-t" }, () => WatermarkConstants.PHOTO_CONFIDENCE_THRESHOLD, "The confidence threshold for watermark detection (0.0 to 1.0).");
            var verboseOption = new Option<bool>(new[] { "--verbose", "-v" }, "Show detailed information during extraction.");
            var debugOption = new Option<bool>(new[] { "--debug", "-d" }, "Show debugging information for detection failures.");
            var noScreenDetectionOption = new Option<bool>("--no-screen-detection", "Disable automatic screen detection and perspective correction.");
            var simpleExtractionOption = new Option<bool>("--simple-extraction", "Use only the simple LSB steganography extraction method.");

            extractCommand.AddArgument(photoPathArg);
            extractCommand.AddOption(thresholdOption);
            extractCommand.AddOption(verboseOption);
            extractCommand.AddOption(debugOption);
            extractCommand.AddOption(noScreenDetectionOption);
            extractCommand.AddOption(simpleExtractionOption);

            extractCommand.SetHandler(async (InvocationContext context) =>
            {
                var photoPath = context.ParseResult.GetValueForArgument(photoPathArg);
                var threshold = context.ParseResult.GetValueForOption(thresholdOption);
                var verbose = context.ParseResult.GetValueForOption(verboseOption);
                var debug = context.ParseResult.GetValueForOption(debugOption);
                var noScreenDetection = context.ParseResult.GetValueForOption(noScreenDetectionOption);
                var simpleExtraction = context.ParseResult.GetValueForOption(simpleExtractionOption);

                await HandleExtractCommand(photoPath, threshold, verbose, debug, noScreenDetection, simpleExtraction);
            });

            return extractCommand;
        }

        private static Command CreateOverlayCommand()
        {
            var overlayCommand = new Command("overlay", "Manage the transparent desktop overlay watermark.");

            overlayCommand.AddCommand(CreateStartOverlayCommand());
            overlayCommand.AddCommand(CreateStopOverlayCommand());
            overlayCommand.AddCommand(CreateStatusOverlayCommand());
            overlayCommand.AddCommand(CreateSaveOverlayCommand());
            overlayCommand.AddCommand(CreateDebugScreenCommand());

            return overlayCommand;
        }

        private static Command CreateStartOverlayCommand()
        {
            var startCommand = new Command("start", "Start the transparent overlay watermark.");

            var overlayTypeArg = new Argument<string?>("overlayType", () => "hybrid", "The overlay type to use. Available types: qr, luminous, steganography, hybrid, beagle. Defaults to 'hybrid'.");
            var opacityOption = new Option<double>(new[] { "--opacity", "-o" }, () => 40.0, "Overlay opacity (1-255).");
            var luminousOption = new Option<bool>("--luminous", "Enable luminous corner markers for enhanced camera detection.");
            var daemonOption = new Option<bool>("--daemon", "Run in daemon mode (background).");
            var verboseOption = new Option<bool>(new[] { "--verbose", "-v" }, "Show detailed information.");
            var debugOption = new Option<bool>(new[] { "--debug", "-d" }, "Show debugging information.");

            startCommand.AddArgument(overlayTypeArg);
            startCommand.AddOption(opacityOption);
            startCommand.AddOption(luminousOption);
            startCommand.AddOption(daemonOption);
            startCommand.AddOption(verboseOption);
            startCommand.AddOption(debugOption);

            startCommand.SetHandler(async (InvocationContext context) =>
            {
                var overlayType = context.ParseResult.GetValueForArgument(overlayTypeArg) ?? "hybrid";
                var opacity = context.ParseResult.GetValueForOption(opacityOption);
                var luminous = context.ParseResult.GetValueForOption(luminousOption);
                var daemon = context.ParseResult.GetValueForOption(daemonOption);
                var verbose = context.ParseResult.GetValueForOption(verboseOption);
                var debug = context.ParseResult.GetValueForOption(debugOption);

                await HandleStartOverlayCommand(overlayType, opacity, luminous, daemon, verbose, debug);
            });

            return startCommand;
        }

        private static Command CreateStopOverlayCommand()
        {
            var stopCommand = new Command("stop", "Stop the overlay watermark.");

            var verboseOption = new Option<bool>(new[] { "--verbose", "-v" }, "Show detailed information.");
            var debugOption = new Option<bool>(new[] { "--debug", "-d" }, "Show debugging information.");

            stopCommand.AddOption(verboseOption);
            stopCommand.AddOption(debugOption);

            stopCommand.SetHandler(async (InvocationContext context) =>
            {
                var verbose = context.ParseResult.GetValueForOption(verboseOption);
                var debug = context.ParseResult.GetValueForOption(debugOption);

                await HandleStopOverlayCommand(verbose, debug);
            });

            return stopCommand;
        }

        private static Command CreateStatusOverlayCommand()
        {
            var statusCommand = new Command("status", "Check overlay status and system information.");

            var verboseOption = new Option<bool>(new[] { "--verbose", "-v" }, "Show detailed system information.");
            var debugOption = new Option<bool>(new[] { "--debug", "-d" }, "Show debugging information.");

            statusCommand.AddOption(verboseOption);
            statusCommand.AddOption(debugOption);

            statusCommand.SetHandler(async (InvocationContext context) =>
            {
                var verbose = context.ParseResult.GetValueForOption(verboseOption);
                var debug = context.ParseResult.GetValueForOption(debugOption);

                await HandleStatusOverlayCommand(verbose, debug);
            });

            return statusCommand;
        }

        private static Command CreateSaveOverlayCommand()
        {
            var saveCommand = new Command("save-overlay", "Save overlay as PNG for testing.");

            var outputPathArg = new Argument<string>("outputPath", "Output file path (must end with .png).");
            var widthOption = new Option<int>("--width", () => 1920, "Image width.");
            var heightOption = new Option<int>("--height", () => 1080, "Image height.");
            var opacityOption = new Option<double>("--opacity", () => 60.0, "Overlay opacity percentage (1-100).");
            var overlayTypeOption = new Option<string>("--overlay-type", () => "hybrid", "Overlay type (qr, luminous, steganography, hybrid, beagle).");
            var verboseOption = new Option<bool>(new[] { "--verbose", "-v" }, "Show detailed information.");
            var debugOption = new Option<bool>(new[] { "--debug", "-d" }, "Show debugging information.");

            saveCommand.AddArgument(outputPathArg);
            saveCommand.AddOption(widthOption);
            saveCommand.AddOption(heightOption);
            saveCommand.AddOption(opacityOption);
            saveCommand.AddOption(overlayTypeOption);
            saveCommand.AddOption(verboseOption);
            saveCommand.AddOption(debugOption);

            saveCommand.SetHandler(async (InvocationContext context) =>
            {
                var outputPath = context.ParseResult.GetValueForArgument(outputPathArg);
                var width = context.ParseResult.GetValueForOption(widthOption);
                var height = context.ParseResult.GetValueForOption(heightOption);
                var opacity = context.ParseResult.GetValueForOption(opacityOption);
                var overlayType = context.ParseResult.GetValueForOption(overlayTypeOption);
                var verbose = context.ParseResult.GetValueForOption(verboseOption);
                var debug = context.ParseResult.GetValueForOption(debugOption);

                await HandleSaveOverlayCommand(outputPath, width, height, opacity, overlayType, verbose, debug);
            });

            return saveCommand;
        }

        private static Command CreateDebugScreenCommand()
        {
            var debugCommand = new Command("debug-screen", "Debug screen resolution and display information.");

            debugCommand.SetHandler(async (InvocationContext context) =>
            {
                await HandleDebugScreenCommand();
            });

            return debugCommand;
        }

        private static async Task HandleExtractCommand(string photoPath, double threshold, bool verbose, bool debug, bool noScreenDetection, bool simpleExtraction)
        {
            try
            {
                Console.WriteLine("Waldo v2.1.0");

                if (threshold < 0.0 || threshold > 1.0)
                {
                    Console.WriteLine($"Error: Threshold must be between 0.0 and 1.0 (provided: {threshold})");
                    return;
                }

                if (!File.Exists(photoPath))
                {
                    Console.WriteLine($"Error: File not found at {photoPath}");
                    return;
                }

                if (verbose)
                {
                    Console.WriteLine($"Using confidence threshold: {threshold}");
                }

                using var image = Image.Load<Rgba32>(photoPath);

                if (simpleExtraction)
                {
                    // Use simple steganography extraction
                    var steganographyResult = SteganographyEngine.ExtractWatermark(image);
                    if (steganographyResult.HasValue)
                    {
                        Console.WriteLine("Watermark detected!");
                        var (userID, watermark, timestamp) = steganographyResult.Value;
                        
                        Console.WriteLine($"Username: {userID}");
                        Console.WriteLine($"Computer-name: {watermark}");
                        Console.WriteLine($"Timestamp: {DateTimeOffset.FromUnixTimeSeconds(timestamp).ToString("MMM dd, yyyy 'at' h:mm:ss tt")}");
                    }
                    else
                    {
                        Console.WriteLine("No watermark detected in the image.");
                    }
                }
                else
                {
                    // Use full watermark extraction pipeline
                    var result = WatermarkEngine.ExtractPhotoResistantWatermark(image, threshold, verbose, debug);
                    if (result != null)
                    {
                        Console.WriteLine("Watermark detected!");
                        
                        var components = result.Split(':');
                        var labels = new[] { "Username", "Computer-name", "Machine-uuid", "Timestamp" };
                        
                        for (int i = 0; i < components.Length && i < labels.Length; i++)
                        {
                            if (labels[i] == "Timestamp" && long.TryParse(components[i], out var timestamp))
                            {
                                var date = DateTimeOffset.FromUnixTimeSeconds(timestamp);
                                Console.WriteLine($"{labels[i]}: {date.ToString("MMM dd, yyyy 'at' h:mm:ss tt")}");
                            }
                            else
                            {
                                Console.WriteLine($"{labels[i]}: {components[i]}");
                            }
                        }
                    }
                    else
                    {
                        Console.WriteLine("No watermark detected in the image.");
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }

        private static async Task HandleStartOverlayCommand(string overlayType, double opacity, bool luminous, bool daemon, bool verbose, bool debug)
        {
            try
            {
                if (opacity < 1 || opacity > 255)
                {
                    Console.WriteLine($"Error: Opacity must be between 1 and 255 (provided: {opacity})");
                    return;
                }

                var normalizedOpacity = opacity / 255.0;
                var success = OverlayManager.Instance.StartOverlay(overlayType, normalizedOpacity, luminous, verbose);

                if (success)
                {
                    if (verbose)
                    {
                        Console.WriteLine($"Overlay started successfully with type: {overlayType}");
                        Console.WriteLine($"Opacity: {opacity}/255 ({normalizedOpacity:P1})");
                        Console.WriteLine($"Luminous markers: {(luminous ? "enabled" : "disabled")}");
                    }
                    else
                    {
                        Console.WriteLine("Overlay started successfully.");
                    }

                    if (!daemon)
                    {
                        Console.WriteLine("Press any key to stop overlay...");
                        Console.ReadKey();
                        OverlayManager.Instance.StopOverlay(verbose);
                    }
                }
                else
                {
                    Console.WriteLine("Failed to start overlay. Overlay may already be running.");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }

        private static async Task HandleStopOverlayCommand(bool verbose, bool debug)
        {
            try
            {
                var success = OverlayManager.Instance.StopOverlay(verbose);
                if (success)
                {
                    Console.WriteLine("Overlay stopped successfully.");
                }
                else
                {
                    Console.WriteLine("No overlay is currently running.");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }

        private static async Task HandleStatusOverlayCommand(bool verbose, bool debug)
        {
            try
            {
                if (verbose)
                {
                    var detailedStatus = OverlayManager.Instance.GetDetailedStatus();
                    Console.WriteLine("=== Waldo Overlay Status ===");
                    Console.WriteLine($"Overlay running: {detailedStatus["isRunning"]}");
                    Console.WriteLine($"Active windows: {detailedStatus["windowCount"]}");
                    Console.WriteLine($"Total screens: {detailedStatus["totalScreens"]}");
                    Console.WriteLine($"Timestamp: {detailedStatus["timestamp"]}");
                    
                    if (detailedStatus["systemInfo"] is Dictionary<string, object> systemInfo)
                    {
                        Console.WriteLine("\n=== System Information ===");
                        foreach (var kvp in systemInfo)
                        {
                            Console.WriteLine($"{kvp.Key}: {kvp.Value}");
                        }
                    }
                }
                else
                {
                    Console.WriteLine(OverlayManager.Instance.GetOverlayStatus());
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }

        private static async Task HandleSaveOverlayCommand(string outputPath, int width, int height, double opacity, string overlayType, bool verbose, bool debug)
        {
            try
            {
                if (!outputPath.EndsWith(".png", StringComparison.OrdinalIgnoreCase))
                {
                    Console.WriteLine($"Error: Output file must have .png extension. Provided: {outputPath}");
                    return;
                }

                if (opacity < 0.1 || opacity > 100)
                {
                    Console.WriteLine($"Error: Opacity must be between 0.1 and 100 percent (provided: {opacity})");
                    return;
                }

                var normalizedOpacity = opacity / 100.0;
                var success = OverlayManager.Instance.SaveOverlay(outputPath, width, height, overlayType, normalizedOpacity, verbose);

                if (success)
                {
                    Console.WriteLine($"Overlay saved to {outputPath}");
                    if (verbose)
                    {
                        Console.WriteLine($"Dimensions: {width}x{height}");
                        Console.WriteLine($"Overlay type: {overlayType}");
                        Console.WriteLine($"Opacity: {opacity}%");
                    }
                }
                else
                {
                    Console.WriteLine("Failed to save overlay.");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }

        private static async Task HandleDebugScreenCommand()
        {
            try
            {
                Console.WriteLine("Display Configuration Debug");
                
                var screens = System.Windows.Forms.Screen.AllScreens;
                Console.WriteLine($"Number of screens: {screens.Length}");
                
                for (int i = 0; i < screens.Length; i++)
                {
                    var screen = screens[i];
                    Console.WriteLine($"\nScreen {i}:");
                    Console.WriteLine($"  Device Name: {screen.DeviceName}");
                    Console.WriteLine($"  Primary: {screen.Primary}");
                    Console.WriteLine($"  Bounds: {screen.Bounds}");
                    Console.WriteLine($"  Working Area: {screen.WorkingArea}");
                    Console.WriteLine($"  BitsPerPixel: {screen.BitsPerPixel}");
                }
                
                var primaryScreen = System.Windows.Forms.Screen.PrimaryScreen;
                Console.WriteLine($"\nPrimary Screen:");
                Console.WriteLine($"  Resolution: {primaryScreen.Bounds.Width}x{primaryScreen.Bounds.Height}");
                Console.WriteLine($"  Working Area: {primaryScreen.WorkingArea.Width}x{primaryScreen.WorkingArea.Height}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }
    }
}