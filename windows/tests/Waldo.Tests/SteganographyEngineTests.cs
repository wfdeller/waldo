using Xunit;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using Waldo.Core;

namespace Waldo.Tests
{
    public class SteganographyEngineTests
    {
        [Fact]
        public void EmbedAndExtractWatermark_ShouldSucceed()
        {
            // Arrange
            var testImage = new Image<Rgba32>(800, 600);
            var testWatermark = "test-watermark-data";
            var testUserID = "test-user";
            
            // Act
            var watermarkedImage = SteganographyEngine.EmbedWatermark(testImage, testWatermark, testUserID);
            Assert.NotNull(watermarkedImage);
            
            var extractedResult = SteganographyEngine.ExtractWatermark(watermarkedImage);
            
            // Assert
            Assert.True(extractedResult.HasValue);
            Assert.Equal(testUserID, extractedResult.Value.userID);
            Assert.Equal(testWatermark, extractedResult.Value.watermark);
            Assert.True(extractedResult.Value.timestamp > 0);
            
            // Cleanup
            testImage.Dispose();
            watermarkedImage.Dispose();
        }
        
        [Fact]
        public void EmbedWatermark_WithLargeData_ShouldSucceed()
        {
            // Arrange
            var testImage = new Image<Rgba32>(1920, 1080);
            var testWatermark = new string('A', 1000); // Large watermark
            var testUserID = "test-user-with-long-name";
            
            // Act
            var watermarkedImage = SteganographyEngine.EmbedWatermark(testImage, testWatermark, testUserID);
            Assert.NotNull(watermarkedImage);
            
            var extractedResult = SteganographyEngine.ExtractWatermark(watermarkedImage);
            
            // Assert
            Assert.True(extractedResult.HasValue);
            Assert.Equal(testUserID, extractedResult.Value.userID);
            Assert.Equal(testWatermark, extractedResult.Value.watermark);
            
            // Cleanup
            testImage.Dispose();
            watermarkedImage.Dispose();
        }
        
        [Fact]
        public void ExtractWatermark_FromCleanImage_ShouldReturnNull()
        {
            // Arrange
            var cleanImage = new Image<Rgba32>(400, 300);
            
            // Act
            var result = SteganographyEngine.ExtractWatermark(cleanImage);
            
            // Assert
            Assert.False(result.HasValue);
            
            // Cleanup
            cleanImage.Dispose();
        }
        
        [Fact]
        public void EmbedWatermark_WithSmallImage_ShouldHandleGracefully()
        {
            // Arrange
            var smallImage = new Image<Rgba32>(100, 100);
            var testWatermark = "small-test";
            var testUserID = "user";
            
            // Act
            var watermarkedImage = SteganographyEngine.EmbedWatermark(smallImage, testWatermark, testUserID);
            
            // Assert
            Assert.NotNull(watermarkedImage);
            
            var extractedResult = SteganographyEngine.ExtractWatermark(watermarkedImage);
            Assert.True(extractedResult.HasValue);
            Assert.Equal(testUserID, extractedResult.Value.userID);
            Assert.Equal(testWatermark, extractedResult.Value.watermark);
            
            // Cleanup
            smallImage.Dispose();
            watermarkedImage.Dispose();
        }
        
        [Theory]
        [InlineData("short")]
        [InlineData("medium-length-watermark-data")]
        [InlineData("very-long-watermark-data-that-contains-multiple-words-and-special-characters-!@#$%")]
        public void EmbedAndExtractWatermark_WithVariousWatermarkLengths_ShouldSucceed(string watermark)
        {
            // Arrange
            var testImage = new Image<Rgba32>(600, 400);
            var testUserID = "test-user";
            
            // Act
            var watermarkedImage = SteganographyEngine.EmbedWatermark(testImage, watermark, testUserID);
            Assert.NotNull(watermarkedImage);
            
            var extractedResult = SteganographyEngine.ExtractWatermark(watermarkedImage);
            
            // Assert
            Assert.True(extractedResult.HasValue);
            Assert.Equal(testUserID, extractedResult.Value.userID);
            Assert.Equal(watermark, extractedResult.Value.watermark);
            
            // Cleanup
            testImage.Dispose();
            watermarkedImage.Dispose();
        }
        
        [Fact]
        public void EmbedWatermark_WithSpecialCharacters_ShouldSucceed()
        {
            // Arrange
            var testImage = new Image<Rgba32>(800, 600);
            var testWatermark = "test:with:colons:and-special!@#$%^&*()_+characters";
            var testUserID = "user-with-special-chars!@#";
            
            // Act
            var watermarkedImage = SteganographyEngine.EmbedWatermark(testImage, testWatermark, testUserID);
            Assert.NotNull(watermarkedImage);
            
            var extractedResult = SteganographyEngine.ExtractWatermark(watermarkedImage);
            
            // Assert
            Assert.True(extractedResult.HasValue);
            Assert.Equal(testUserID, extractedResult.Value.userID);
            Assert.Equal(testWatermark, extractedResult.Value.watermark);
            
            // Cleanup
            testImage.Dispose();
            watermarkedImage.Dispose();
        }
    }
}