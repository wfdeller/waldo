using System;
using System.Management;
using System.Net;
using System.Security.Principal;
using System.Text;

namespace Waldo.Windows
{
    public class SystemInfo
    {
        public static string GetCurrentWatermarkData()
        {
            var username = GetUsername();
            var computerName = GetComputerName();
            var machineUUID = GetMachineUUID();
            var timestamp = GetCurrentTimestamp();
            
            return $"{username}:{computerName}:{machineUUID}:{timestamp}";
        }
        
        public static string GetUsername()
        {
            return Environment.UserName;
        }
        
        public static string GetFullName()
        {
            try
            {
                var identity = WindowsIdentity.GetCurrent();
                return identity.Name ?? Environment.UserName;
            }
            catch
            {
                return Environment.UserName;
            }
        }
        
        public static string GetComputerName()
        {
            return Environment.MachineName;
        }
        
        public static string GetMachineUUID()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT UUID FROM Win32_ComputerSystemProduct");
                foreach (ManagementObject obj in searcher.Get())
                {
                    var uuid = obj["UUID"]?.ToString();
                    if (!string.IsNullOrEmpty(uuid))
                        return uuid;
                }
                
                // Fallback to motherboard serial number
                using var mbSearcher = new ManagementObjectSearcher("SELECT SerialNumber FROM Win32_BaseBoard");
                foreach (ManagementObject obj in mbSearcher.Get())
                {
                    var serial = obj["SerialNumber"]?.ToString();
                    if (!string.IsNullOrEmpty(serial))
                        return serial;
                }
                
                // Final fallback to machine GUID
                return GetMachineGuid();
            }
            catch
            {
                return GetMachineGuid();
            }
        }
        
        private static string GetMachineGuid()
        {
            try
            {
                using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Cryptography");
                var guid = key?.GetValue("MachineGuid")?.ToString();
                return guid ?? Guid.NewGuid().ToString();
            }
            catch
            {
                return Guid.NewGuid().ToString();
            }
        }
        
        public static string? GetSystemSerialNumber()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT SerialNumber FROM Win32_ComputerSystem");
                foreach (ManagementObject obj in searcher.Get())
                {
                    var serial = obj["SerialNumber"]?.ToString();
                    if (!string.IsNullOrEmpty(serial))
                        return serial;
                }
                return null;
            }
            catch
            {
                return null;
            }
        }
        
        public static int GetCurrentTimestamp()
        {
            return (int)DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        }
        
        public static int GetHourlyTimestamp()
        {
            var now = DateTime.UtcNow;
            var hourlyDate = new DateTime(now.Year, now.Month, now.Day, now.Hour, 0, 0, DateTimeKind.Utc);
            return (int)new DateTimeOffset(hourlyDate).ToUnixTimeSeconds();
        }
        
        public static string GetFormattedTimestamp()
        {
            return DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
        }
        
        public static Dictionary<string, object> GetSystemInfo()
        {
            return new Dictionary<string, object>
            {
                ["username"] = GetUsername(),
                ["fullName"] = GetFullName(),
                ["computerName"] = GetComputerName(),
                ["machineUUID"] = GetMachineUUID(),
                ["serialNumber"] = GetSystemSerialNumber() ?? "unknown",
                ["timestamp"] = GetCurrentTimestamp(),
                ["formattedTimestamp"] = GetFormattedTimestamp(),
                ["osVersion"] = Environment.OSVersion.ToString(),
                ["hostname"] = Dns.GetHostName()
            };
        }
        
        public static string GetWatermarkDataWithHourlyTimestamp()
        {
            var username = GetUsername();
            var computerName = GetComputerName();
            var machineUUID = GetMachineUUID();
            var hourlyTimestamp = GetHourlyTimestamp();
            
            return $"{username}:{computerName}:{machineUUID}:{hourlyTimestamp}";
        }
        
        public static (string? username, string? computerName, string? machineUUID, int? timestamp)? ParseWatermarkData(string watermarkString)
        {
            var components = watermarkString.Split(':');
            if (components.Length < 4) return null;
            
            var username = string.IsNullOrEmpty(components[0]) ? null : components[0];
            var computerName = string.IsNullOrEmpty(components[1]) ? null : components[1];
            var machineUUID = string.IsNullOrEmpty(components[2]) ? null : components[2];
            var timestamp = int.TryParse(components[3], out var ts) ? ts : (int?)null;
            
            return (username, computerName, machineUUID, timestamp);
        }
    }
}