using Xunit;
using Waldo.Windows;
using System;

namespace Waldo.Tests
{
    public class SystemInfoTests
    {
        [Fact]
        public void GetUsername_ShouldReturnNonEmptyString()
        {
            // Act
            var username = SystemInfo.GetUsername();
            
            // Assert
            Assert.False(string.IsNullOrEmpty(username));
        }
        
        [Fact]
        public void GetComputerName_ShouldReturnNonEmptyString()
        {
            // Act
            var computerName = SystemInfo.GetComputerName();
            
            // Assert
            Assert.False(string.IsNullOrEmpty(computerName));
        }
        
        [Fact]
        public void GetMachineUUID_ShouldReturnValidUUID()
        {
            // Act
            var uuid = SystemInfo.GetMachineUUID();
            
            // Assert
            Assert.False(string.IsNullOrEmpty(uuid));
            // UUID should be at least 8 characters long
            Assert.True(uuid.Length >= 8);
        }
        
        [Fact]
        public void GetCurrentTimestamp_ShouldReturnValidTimestamp()
        {
            // Arrange
            var beforeCall = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            
            // Act
            var timestamp = SystemInfo.GetCurrentTimestamp();
            
            // Arrange
            var afterCall = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            
            // Assert
            Assert.True(timestamp >= beforeCall);
            Assert.True(timestamp <= afterCall);
        }
        
        [Fact]
        public void GetHourlyTimestamp_ShouldReturnRoundedTimestamp()
        {
            // Act
            var hourlyTimestamp = SystemInfo.GetHourlyTimestamp();
            var currentTimestamp = SystemInfo.GetCurrentTimestamp();
            
            // Assert
            Assert.True(hourlyTimestamp <= currentTimestamp);
            
            // Hourly timestamp should be on the hour boundary
            var hourlyDate = DateTimeOffset.FromUnixTimeSeconds(hourlyTimestamp);
            Assert.Equal(0, hourlyDate.Minute);
            Assert.Equal(0, hourlyDate.Second);
        }
        
        [Fact]
        public void GetCurrentWatermarkData_ShouldContainAllComponents()
        {
            // Act
            var watermarkData = SystemInfo.GetCurrentWatermarkData();
            
            // Assert
            Assert.False(string.IsNullOrEmpty(watermarkData));
            
            var components = watermarkData.Split(':');
            Assert.True(components.Length >= 4);
            
            // Check that components are not empty
            Assert.False(string.IsNullOrEmpty(components[0])); // username
            Assert.False(string.IsNullOrEmpty(components[1])); // computer name
            Assert.False(string.IsNullOrEmpty(components[2])); // machine UUID
            Assert.False(string.IsNullOrEmpty(components[3])); // timestamp
            
            // Check that timestamp is a valid number
            Assert.True(int.TryParse(components[3], out _));
        }
        
        [Fact]
        public void GetSystemInfo_ShouldReturnValidDictionary()
        {
            // Act
            var systemInfo = SystemInfo.GetSystemInfo();
            
            // Assert
            Assert.NotNull(systemInfo);
            Assert.True(systemInfo.ContainsKey("username"));
            Assert.True(systemInfo.ContainsKey("computerName"));
            Assert.True(systemInfo.ContainsKey("machineUUID"));
            Assert.True(systemInfo.ContainsKey("timestamp"));
            Assert.True(systemInfo.ContainsKey("osVersion"));
            
            // Check that values are not null or empty
            Assert.False(string.IsNullOrEmpty(systemInfo["username"].ToString()));
            Assert.False(string.IsNullOrEmpty(systemInfo["computerName"].ToString()));
            Assert.False(string.IsNullOrEmpty(systemInfo["machineUUID"].ToString()));
        }
        
        [Fact]
        public void ParseWatermarkData_WithValidData_ShouldSucceed()
        {
            // Arrange
            var testData = "testuser:testcomputer:test-uuid-123:1703875200";
            
            // Act
            var result = SystemInfo.ParseWatermarkData(testData);
            
            // Assert
            Assert.NotNull(result);
            Assert.Equal("testuser", result.Value.username);
            Assert.Equal("testcomputer", result.Value.computerName);
            Assert.Equal("test-uuid-123", result.Value.machineUUID);
            Assert.Equal(1703875200, result.Value.timestamp);
        }
        
        [Fact]
        public void ParseWatermarkData_WithInvalidData_ShouldReturnNull()
        {
            // Arrange
            var invalidData = "incomplete:data";
            
            // Act
            var result = SystemInfo.ParseWatermarkData(invalidData);
            
            // Assert
            Assert.Null(result);
        }
        
        [Fact]
        public void ParseWatermarkData_WithInvalidTimestamp_ShouldReturnNull()
        {
            // Arrange
            var invalidData = "testuser:testcomputer:test-uuid:invalid-timestamp";
            
            // Act
            var result = SystemInfo.ParseWatermarkData(invalidData);
            
            // Assert
            Assert.Null(result);
        }
        
        [Fact]
        public void GetFormattedTimestamp_ShouldReturnValidFormat()
        {
            // Act
            var formattedTimestamp = SystemInfo.GetFormattedTimestamp();
            
            // Assert
            Assert.False(string.IsNullOrEmpty(formattedTimestamp));
            Assert.Contains("-", formattedTimestamp); // Should contain date separators
            Assert.Contains(":", formattedTimestamp); // Should contain time separators
            
            // Should be parseable as DateTime
            Assert.True(DateTime.TryParse(formattedTimestamp, out _));
        }
    }
}