using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Waldo.Core
{
    public class SteganographyEngine
    {
        public static Image<Rgba32>? EmbedWatermark(Image<Rgba32> image, string watermark, string userID)
        {
            string fullWatermark = $"{userID}:{watermark}:{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";
            byte[] watermarkData = Encoding.UTF8.GetBytes(fullWatermark);
            
            var pixelData = ExtractPixelData(image);
            if (pixelData == null) return null;
            
            var modifiedPixelData = new byte[pixelData.Length];
            Array.Copy(pixelData, modifiedPixelData, pixelData.Length);
            
            int totalPixels = image.Width * image.Height;
            var watermarkBits = watermarkData.SelectMany(b => 
                Enumerable.Range(0, 8).Select(i => (byte)((b >> i) & 1))
            ).ToArray();
            
            var lengthBits = BitConverter.GetBytes((uint)watermarkBits.Length)
                .Reverse() // Big endian
                .SelectMany(b => Enumerable.Range(0, 8).Select(i => (byte)((b >> i) & 1)))
                .ToArray();
            
            var allBits = lengthBits.Concat(watermarkBits).ToArray();
            
            if (allBits.Length > totalPixels * 3) return null;
            
            for (int i = 0; i < allBits.Length; i++)
            {
                int pixelIndex = (i / 3) * 4 + (i % 3);
                if (pixelIndex < modifiedPixelData.Length)
                {
                    modifiedPixelData[pixelIndex] = (byte)((modifiedPixelData[pixelIndex] & 0xFE) | allBits[i]);
                }
            }
            
            return CreateImage(modifiedPixelData, image.Width, image.Height);
        }
        
        public static (string userID, string watermark, long timestamp)? ExtractWatermark(Image<Rgba32> image)
        {
            var pixelData = ExtractPixelData(image);
            if (pixelData == null) return null;
            
            var lengthBits = new byte[32];
            for (int i = 0; i < 32; i++)
            {
                int pixelIndex = (i / 3) * 4 + (i % 3);
                if (pixelIndex >= pixelData.Length) return null;
                lengthBits[i] = (byte)(pixelData[pixelIndex] & 1);
            }
            
            var lengthBytes = new byte[4];
            for (int i = 0; i < 4; i++)
            {
                byte value = 0;
                for (int j = 0; j < 8; j++)
                {
                    value |= (byte)(lengthBits[i * 8 + j] << j);
                }
                lengthBytes[i] = value;
            }
            
            Array.Reverse(lengthBytes); // Convert from big endian
            int watermarkLength = BitConverter.ToInt32(lengthBytes, 0);
            
            if (watermarkLength <= 0 || watermarkLength > 10000) return null;
            
            var watermarkBits = new byte[watermarkLength];
            for (int i = 0; i < watermarkLength; i++)
            {
                int bitIndex = 32 + i;
                int pixelIndex = (bitIndex / 3) * 4 + (bitIndex % 3);
                if (pixelIndex >= pixelData.Length) return null;
                watermarkBits[i] = (byte)(pixelData[pixelIndex] & 1);
            }
            
            var watermarkBytes = new byte[watermarkLength / 8];
            for (int i = 0; i < watermarkBytes.Length; i++)
            {
                byte value = 0;
                for (int j = 0; j < 8; j++)
                {
                    if (i * 8 + j < watermarkBits.Length)
                    {
                        value |= (byte)(watermarkBits[i * 8 + j] << j);
                    }
                }
                watermarkBytes[i] = value;
            }
            
            string watermarkString = Encoding.UTF8.GetString(watermarkBytes);
            if (string.IsNullOrEmpty(watermarkString)) return null;
            
            var components = watermarkString.Split(':');
            if (components.Length < 3) return null;
            
            if (!long.TryParse(components[^1], out long timestamp)) return null;
            
            string userID = components[0];
            string watermark = string.Join(":", components[1..^1]);
            
            return (userID, watermark, timestamp);
        }
        
        private static byte[]? ExtractPixelData(Image<Rgba32> image)
        {
            var pixelData = new byte[image.Width * image.Height * 4];
            
            image.ProcessPixelRows(accessor =>
            {
                int index = 0;
                for (int y = 0; y < accessor.Height; y++)
                {
                    var row = accessor.GetRowSpan(y);
                    for (int x = 0; x < row.Length; x++)
                    {
                        var pixel = row[x];
                        pixelData[index++] = pixel.R;
                        pixelData[index++] = pixel.G;
                        pixelData[index++] = pixel.B;
                        pixelData[index++] = pixel.A;
                    }
                }
            });
            
            return pixelData;
        }
        
        private static Image<Rgba32>? CreateImage(byte[] pixelData, int width, int height)
        {
            var image = new Image<Rgba32>(width, height);
            
            image.ProcessPixelRows(accessor =>
            {
                int index = 0;
                for (int y = 0; y < accessor.Height; y++)
                {
                    var row = accessor.GetRowSpan(y);
                    for (int x = 0; x < row.Length; x++)
                    {
                        if (index + 3 < pixelData.Length)
                        {
                            row[x] = new Rgba32(
                                pixelData[index++],
                                pixelData[index++],
                                pixelData[index++],
                                pixelData[index++]
                            );
                        }
                    }
                }
            });
            
            return image;
        }
    }
}