import XCTest
@testable import Waldo

final class WaldoTests: XCTestCase {
    
    func testSystemInfoGeneration() throws {
        let systemInfo = SystemInfo.getSystemInfo()
        
        XCTAssertNotNil(systemInfo["username"])
        XCTAssertNotNil(systemInfo["computerName"])
        XCTAssertNotNil(systemInfo["machineUUID"])
        XCTAssertNotNil(systemInfo["timestamp"])
    }
    
    func testWatermarkDataGeneration() throws {
        let watermarkData = SystemInfo.getWatermarkDataWithHourlyTimestamp()
        let components = watermarkData.components(separatedBy: ":")
        
        XCTAssertEqual(components.count, 4, "Watermark should have 4 components")
        XCTAssertFalse(components[0].isEmpty, "Username should not be empty")
        XCTAssertFalse(components[1].isEmpty, "Computer name should not be empty")
        XCTAssertFalse(components[2].isEmpty, "Machine UUID should not be empty")
        XCTAssertFalse(components[3].isEmpty, "Timestamp should not be empty")
    }
    
    func testWatermarkDataParsing() throws {
        let testWatermark = "testuser:TestMac:ABC123:1703875200"
        let parsed = SystemInfo.parseWatermarkData(testWatermark)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.username, "testuser")
        XCTAssertEqual(parsed?.computerName, "TestMac") 
        XCTAssertEqual(parsed?.machineUUID, "ABC123")
        XCTAssertEqual(parsed?.timestamp, 1703875200)
    }
    
}