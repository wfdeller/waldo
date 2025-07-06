using System;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using System.Windows.Threading;
using Waldo.Core;
using QRCoder;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;

namespace Waldo.Windows
{
    public partial class OverlayWindow : Window
    {
        private Timer? _refreshTimer;
        private string _overlayType = "hybrid";
        private double _opacity = 0.4;
        private bool _luminousEnabled = false;
        
        public OverlayWindow(string overlayType = "hybrid", double opacity = 0.4, bool luminousEnabled = false)
        {
            InitializeComponent();
            _overlayType = overlayType;
            _opacity = opacity;
            _luminousEnabled = luminousEnabled;
            
            // Set window properties for overlay
            this.Left = 0;
            this.Top = 0;
            this.Width = SystemParameters.PrimaryScreenWidth;
            this.Height = SystemParameters.PrimaryScreenHeight;
            
            // Start hourly refresh timer
            _refreshTimer = new Timer(RefreshOverlay, null, TimeSpan.Zero, TimeSpan.FromHours(1));
        }
        
        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            RefreshOverlay(null);
        }
        
        private void RefreshOverlay(object? state)
        {
            Dispatcher.Invoke(() =>
            {
                try
                {
                    RenderOverlay();
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error refreshing overlay: {ex.Message}");
                }
            });
        }
        
        private void RenderOverlay()
        {
            OverlayCanvas.Children.Clear();
            
            var watermarkData = SystemInfo.GetWatermarkDataWithHourlyTimestamp();
            
            switch (_overlayType.ToLower())
            {
                case "qr":
                    RenderQROverlay(watermarkData);
                    break;
                case "luminous":
                    RenderLuminousOverlay(watermarkData);
                    break;
                case "steganography":
                    RenderSteganographyOverlay(watermarkData);
                    break;
                case "beagle":
                    RenderBeagleOverlay(watermarkData);
                    break;
                case "hybrid":
                default:
                    RenderHybridOverlay(watermarkData);
                    break;
            }
            
            if (_luminousEnabled)
            {
                RenderLuminousMarkers();
            }
        }
        
        private void RenderQROverlay(string data)
        {
            var qrGenerator = new QRCodeGenerator();
            var qrCodeData = qrGenerator.CreateQrCode(data, QRCodeGenerator.ECCLevel.H);
            var qrCode = new QRCode(qrCodeData);
            
            var qrBitmap = qrCode.GetGraphic(WatermarkConstants.QR_VERSION2_PIXELS_PER_MODULE);
            
            // Convert to WPF format and place in corners
            var corners = GetCornerPositions();
            foreach (var corner in corners)
            {
                var image = new System.Windows.Controls.Image
                {
                    Source = ConvertToWpfBitmap(qrBitmap),
                    Width = WatermarkConstants.QR_VERSION2_PIXEL_SIZE,
                    Height = WatermarkConstants.QR_VERSION2_PIXEL_SIZE,
                    Opacity = _opacity
                };
                
                Canvas.SetLeft(image, corner.X);
                Canvas.SetTop(image, corner.Y);
                OverlayCanvas.Children.Add(image);
            }
        }
        
        private void RenderLuminousOverlay(string data)
        {
            // Create luminous patterns across the screen
            var patternSize = WatermarkConstants.PATTERN_SIZE;
            var screenWidth = (int)SystemParameters.PrimaryScreenWidth;
            var screenHeight = (int)SystemParameters.PrimaryScreenHeight;
            
            for (int x = 0; x < screenWidth; x += patternSize)
            {
                for (int y = 0; y < screenHeight; y += patternSize)
                {
                    var rect = new Rectangle
                    {
                        Width = patternSize,
                        Height = patternSize,
                        Fill = new SolidColorBrush(System.Windows.Media.Color.FromArgb(
                            (byte)(WatermarkConstants.ALPHA_OPACITY),
                            (byte)(WatermarkConstants.RGB_HIGH),
                            (byte)(WatermarkConstants.RGB_HIGH),
                            (byte)(WatermarkConstants.RGB_HIGH)
                        ))
                    };
                    
                    Canvas.SetLeft(rect, x);
                    Canvas.SetTop(rect, y);
                    OverlayCanvas.Children.Add(rect);
                }
            }
        }
        
        private void RenderSteganographyOverlay(string data)
        {
            // Create a transparent overlay with steganographic data
            var screenWidth = (int)SystemParameters.PrimaryScreenWidth;
            var screenHeight = (int)SystemParameters.PrimaryScreenHeight;
            
            using var image = new SixLabors.ImageSharp.Image<Rgba32>(screenWidth, screenHeight);
            
            // Fill with transparent background
            image.Mutate(ctx => ctx.BackgroundColor(SixLabors.ImageSharp.Color.Transparent));
            
            // Embed watermark using steganography
            var watermarkedImage = SteganographyEngine.EmbedWatermark(image, data, SystemInfo.GetUsername());
            
            if (watermarkedImage != null)
            {
                // Convert to WPF and display
                var wpfImage = ConvertImageSharpToWpf(watermarkedImage);
                var imageControl = new System.Windows.Controls.Image
                {
                    Source = wpfImage,
                    Width = screenWidth,
                    Height = screenHeight,
                    Opacity = _opacity
                };
                
                OverlayCanvas.Children.Add(imageControl);
            }
        }
        
        private void RenderBeagleOverlay(string data)
        {
            // Simple wireframe beagle for testing
            var beagleText = new TextBlock
            {
                Text = $"🐕 Waldo Beagle Overlay - {SystemInfo.GetUsername()}",
                FontSize = 24,
                Foreground = new SolidColorBrush(System.Windows.Media.Color.FromArgb(
                    (byte)(255 * _opacity),
                    255, 255, 255
                ))
            };
            
            Canvas.SetLeft(beagleText, 100);
            Canvas.SetTop(beagleText, 100);
            OverlayCanvas.Children.Add(beagleText);
        }
        
        private void RenderHybridOverlay(string data)
        {
            // Combine QR codes, luminous patterns, and steganography
            RenderQROverlay(data);
            RenderLuminousPatterns();
            RenderSteganographyOverlay(data);
        }
        
        private void RenderLuminousPatterns()
        {
            // Add subtle luminous patterns
            var patternSize = WatermarkConstants.PATTERN_SIZE / 2;
            var screenWidth = (int)SystemParameters.PrimaryScreenWidth;
            var screenHeight = (int)SystemParameters.PrimaryScreenHeight;
            
            for (int x = patternSize; x < screenWidth - patternSize; x += patternSize * 2)
            {
                for (int y = patternSize; y < screenHeight - patternSize; y += patternSize * 2)
                {
                    var ellipse = new Ellipse
                    {
                        Width = 4,
                        Height = 4,
                        Fill = new SolidColorBrush(System.Windows.Media.Color.FromArgb(
                            (byte)(WatermarkConstants.ALPHA_OPACITY / 2),
                            (byte)(WatermarkConstants.RGB_HIGH),
                            (byte)(WatermarkConstants.RGB_HIGH),
                            (byte)(WatermarkConstants.RGB_HIGH)
                        ))
                    };
                    
                    Canvas.SetLeft(ellipse, x);
                    Canvas.SetTop(ellipse, y);
                    OverlayCanvas.Children.Add(ellipse);
                }
            }
        }
        
        private void RenderLuminousMarkers()
        {
            // Add luminous corner markers
            var corners = GetCornerPositions();
            foreach (var corner in corners)
            {
                var marker = new Rectangle
                {
                    Width = 20,
                    Height = 20,
                    Fill = new SolidColorBrush(System.Windows.Media.Color.FromArgb(
                        (byte)(WatermarkConstants.ALPHA_OPACITY * 2),
                        255, 255, 255
                    ))
                };
                
                Canvas.SetLeft(marker, corner.X - 10);
                Canvas.SetTop(marker, corner.Y - 10);
                OverlayCanvas.Children.Add(marker);
            }
        }
        
        private Point[] GetCornerPositions()
        {
            var margin = WatermarkConstants.QR_VERSION2_MARGIN;
            var menuBarOffset = WatermarkConstants.QR_VERSION2_MENU_BAR_OFFSET;
            var screenWidth = SystemParameters.PrimaryScreenWidth;
            var screenHeight = SystemParameters.PrimaryScreenHeight;
            
            return new[]
            {
                new Point(margin, margin + menuBarOffset), // Top-left
                new Point(screenWidth - WatermarkConstants.QR_VERSION2_PIXEL_SIZE - margin, margin + menuBarOffset), // Top-right
                new Point(margin, screenHeight - WatermarkConstants.QR_VERSION2_PIXEL_SIZE - margin), // Bottom-left
                new Point(screenWidth - WatermarkConstants.QR_VERSION2_PIXEL_SIZE - margin, screenHeight - WatermarkConstants.QR_VERSION2_PIXEL_SIZE - margin) // Bottom-right
            };
        }
        
        private BitmapSource ConvertToWpfBitmap(System.Drawing.Bitmap bitmap)
        {
            var hBitmap = bitmap.GetHbitmap();
            try
            {
                return System.Windows.Interop.Imaging.CreateBitmapSourceFromHBitmap(
                    hBitmap,
                    IntPtr.Zero,
                    Int32Rect.Empty,
                    BitmapSizeOptions.FromEmptyOptions());
            }
            finally
            {
                DeleteObject(hBitmap);
            }
        }
        
        private BitmapSource ConvertImageSharpToWpf(SixLabors.ImageSharp.Image<Rgba32> image)
        {
            using var memoryStream = new System.IO.MemoryStream();
            image.SaveAsPng(memoryStream);
            memoryStream.Position = 0;
            
            var bitmapImage = new BitmapImage();
            bitmapImage.BeginInit();
            bitmapImage.CacheOption = BitmapCacheOption.OnLoad;
            bitmapImage.StreamSource = memoryStream;
            bitmapImage.EndInit();
            bitmapImage.Freeze();
            
            return bitmapImage;
        }
        
        [System.Runtime.InteropServices.DllImport("gdi32.dll")]
        private static extern bool DeleteObject(IntPtr hObject);
        
        protected override void OnClosed(EventArgs e)
        {
            _refreshTimer?.Dispose();
            base.OnClosed(e);
        }
    }
}