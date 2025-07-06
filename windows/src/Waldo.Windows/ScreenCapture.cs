using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;

namespace Waldo.Windows
{
    public class ScreenCapture
    {
        [DllImport("user32.dll")]
        private static extern IntPtr GetDesktopWindow();
        
        [DllImport("user32.dll")]
        private static extern IntPtr GetWindowDC(IntPtr hWnd);
        
        [DllImport("user32.dll")]
        private static extern IntPtr ReleaseDC(IntPtr hWnd, IntPtr hDC);
        
        [DllImport("gdi32.dll")]
        private static extern IntPtr CreateCompatibleDC(IntPtr hdc);
        
        [DllImport("gdi32.dll")]
        private static extern IntPtr CreateCompatibleBitmap(IntPtr hdc, int nWidth, int nHeight);
        
        [DllImport("gdi32.dll")]
        private static extern IntPtr SelectObject(IntPtr hdc, IntPtr hgdiobj);
        
        [DllImport("gdi32.dll")]
        private static extern bool BitBlt(IntPtr hdc, int nXDest, int nYDest, int nWidth, int nHeight, IntPtr hdcSrc, int nXSrc, int nYSrc, uint dwRop);
        
        [DllImport("gdi32.dll")]
        private static extern bool DeleteObject(IntPtr hObject);
        
        [DllImport("gdi32.dll")]
        private static extern bool DeleteDC(IntPtr hdc);
        
        private const uint SRCCOPY = 0x00CC0020;
        
        public static System.Drawing.Image<Rgba32>? CaptureDesktop()
        {
            var bounds = Screen.PrimaryScreen.Bounds;
            return CaptureDesktop(bounds.Width, bounds.Height);
        }
        
        public static System.Drawing.Image<Rgba32>? CaptureDesktop(int width, int height)
        {
            IntPtr desktopHwnd = GetDesktopWindow();
            IntPtr desktopDC = GetWindowDC(desktopHwnd);
            IntPtr memoryDC = CreateCompatibleDC(desktopDC);
            IntPtr bitmap = CreateCompatibleBitmap(desktopDC, width, height);
            
            if (bitmap == IntPtr.Zero)
            {
                ReleaseDC(desktopHwnd, desktopDC);
                DeleteDC(memoryDC);
                return null;
            }
            
            IntPtr oldBitmap = SelectObject(memoryDC, bitmap);
            
            bool success = BitBlt(memoryDC, 0, 0, width, height, desktopDC, 0, 0, SRCCOPY);
            
            if (!success)
            {
                SelectObject(memoryDC, oldBitmap);
                DeleteObject(bitmap);
                DeleteDC(memoryDC);
                ReleaseDC(desktopHwnd, desktopDC);
                return null;
            }
            
            try
            {
                var gdiBitmap = System.Drawing.Image.FromHbitmap(bitmap);
                var result = ConvertToImageSharp(gdiBitmap);
                gdiBitmap.Dispose();
                return result;
            }
            finally
            {
                SelectObject(memoryDC, oldBitmap);
                DeleteObject(bitmap);
                DeleteDC(memoryDC);
                ReleaseDC(desktopHwnd, desktopDC);
            }
        }
        
        public static System.Drawing.Image<Rgba32>? CaptureScreen(int screenIndex)
        {
            if (screenIndex < 0 || screenIndex >= Screen.AllScreens.Length)
                return null;
                
            var screen = Screen.AllScreens[screenIndex];
            var bounds = screen.Bounds;
            
            return CaptureDesktop(bounds.Width, bounds.Height);
        }
        
        public static Screen[] GetAllScreens()
        {
            return Screen.AllScreens;
        }
        
        public static Screen GetPrimaryScreen()
        {
            return Screen.PrimaryScreen;
        }
        
        public static (int width, int height) GetScreenSize()
        {
            var screen = Screen.PrimaryScreen;
            return (screen.Bounds.Width, screen.Bounds.Height);
        }
        
        public static (int width, int height) GetScreenSize(int screenIndex)
        {
            if (screenIndex < 0 || screenIndex >= Screen.AllScreens.Length)
                return (0, 0);
                
            var screen = Screen.AllScreens[screenIndex];
            return (screen.Bounds.Width, screen.Bounds.Height);
        }
        
        public static Rectangle GetScreenBounds(int screenIndex)
        {
            if (screenIndex < 0 || screenIndex >= Screen.AllScreens.Length)
                return Rectangle.Empty;
                
            var screen = Screen.AllScreens[screenIndex];
            return screen.Bounds;
        }
        
        public static bool SaveScreenshot(string filePath)
        {
            try
            {
                var image = CaptureDesktop();
                if (image == null) return false;
                
                image.SaveAsPng(filePath);
                image.Dispose();
                return true;
            }
            catch
            {
                return false;
            }
        }
        
        private static System.Drawing.Image<Rgba32> ConvertToImageSharp(System.Drawing.Image gdiImage)
        {
            using var bitmap = new System.Drawing.Bitmap(gdiImage);
            var imageSharp = new System.Drawing.Image<Rgba32>(bitmap.Width, bitmap.Height);
            
            var bitmapData = bitmap.LockBits(
                new System.Drawing.Rectangle(0, 0, bitmap.Width, bitmap.Height),
                ImageLockMode.ReadOnly,
                PixelFormat.Format32bppArgb);
            
            try
            {
                imageSharp.ProcessPixelRows(accessor =>
                {
                    for (int y = 0; y < accessor.Height; y++)
                    {
                        var row = accessor.GetRowSpan(y);
                        var ptr = bitmapData.Scan0 + (y * bitmapData.Stride);
                        
                        for (int x = 0; x < row.Length; x++)
                        {
                            var pixel = Marshal.ReadInt32(ptr, x * 4);
                            var b = (byte)(pixel & 0xFF);
                            var g = (byte)((pixel >> 8) & 0xFF);
                            var r = (byte)((pixel >> 16) & 0xFF);
                            var a = (byte)((pixel >> 24) & 0xFF);
                            
                            row[x] = new Rgba32(r, g, b, a);
                        }
                    }
                });
            }
            finally
            {
                bitmap.UnlockBits(bitmapData);
            }
            
            return imageSharp;
        }
    }
}