import Foundation
import IOKit

class SystemInfo {
    
    static func getCurrentWatermarkData() -> String {
        let username = getUsername()
        let computerName = getComputerName()
        let machineUUID = getMachineUUID()
        let timestamp = getCurrentTimestamp()
        
        return "\(username):\(computerName):\(machineUUID):\(timestamp)"
    }
    
    static func getUsername() -> String {
        return NSUserName()
    }
    
    static func getFullName() -> String {
        return NSFullUserName()
    }
    
    static func getComputerName() -> String {
        return Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    }
    
    static func getMachineUUID() -> String {
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        
        guard platformExpert > 0 else {
            return ProcessInfo.processInfo.globallyUniqueString
        }
        
        guard let serialNumberAsCFString = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        ) else {
            IOObjectRelease(platformExpert)
            return ProcessInfo.processInfo.globallyUniqueString
        }
        
        IOObjectRelease(platformExpert)
        
        let uuid = serialNumberAsCFString.takeRetainedValue() as! CFString
        return uuid as String
    }
    
    static func getSystemSerialNumber() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        
        guard platformExpert > 0 else { return nil }
        
        guard let serialNumberAsCFString = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformSerialNumberKey as CFString,
            kCFAllocatorDefault,
            0
        ) else {
            IOObjectRelease(platformExpert)
            return nil
        }
        
        IOObjectRelease(platformExpert)
        
        let serialNumber = serialNumberAsCFString.takeRetainedValue() as! CFString
        return serialNumber as String
    }
    
    static func getCurrentTimestamp() -> Int {
        return Int(Date().timeIntervalSince1970)
    }
    
    static func getHourlyTimestamp() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        let hourlyDate = calendar.date(from: components) ?? now
        return Int(hourlyDate.timeIntervalSince1970)
    }
    
    static func getFormattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    static func getSystemInfo() -> [String: Any] {
        return [
            "username": getUsername(),
            "fullName": getFullName(),
            "computerName": getComputerName(),
            "machineUUID": getMachineUUID(),
            "serialNumber": getSystemSerialNumber() ?? "unknown",
            "timestamp": getCurrentTimestamp(),
            "formattedTimestamp": getFormattedTimestamp(),
            "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "hostname": ProcessInfo.processInfo.hostName
        ]
    }
    
    static func getWatermarkDataWithHourlyTimestamp() -> String {
        let username = getUsername()
        let computerName = getComputerName()
        let machineUUID = getMachineUUID()
        let hourlyTimestamp = getHourlyTimestamp()
        
        return "\(username):\(computerName):\(machineUUID):\(hourlyTimestamp)"
    }
    
    static func parseWatermarkData(_ watermarkString: String) -> (username: String?, computerName: String?, machineUUID: String?, timestamp: Int?)? {
        let components = watermarkString.components(separatedBy: ":")
        guard components.count >= 4 else { return nil }
        
        let username = components[0].isEmpty ? nil : components[0]
        let computerName = components[1].isEmpty ? nil : components[1]
        let machineUUID = components[2].isEmpty ? nil : components[2]
        let timestamp = Int(components[3])
        
        return (username: username, computerName: computerName, machineUUID: machineUUID, timestamp: timestamp)
    }
}