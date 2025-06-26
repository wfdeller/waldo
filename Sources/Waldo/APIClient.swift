import Foundation

class APIClient {
    static let shared = APIClient()
    
    private let baseURL: String
    private let session: URLSession
    private var offlineQueue: [(event: [String: Any], retryCount: Int)] = []
    private let maxRetries = 3
    
    private init() {
        self.baseURL = ProcessInfo.processInfo.environment["WALDO_API_URL"] ?? "http://localhost:3000/api"
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    func logEvent(eventType: String, watermarkData: String, metadata: [String: Any] = [:]) {
        let event = createEventPayload(eventType: eventType, watermarkData: watermarkData, metadata: metadata)
        sendEvent(event)
    }
    
    func logExtraction(watermarkData: String, photoPath: String?, confidence: Double = 1.0) {
        var metadata: [String: Any] = ["confidence": confidence]
        if let photoPath = photoPath {
            metadata["photoPath"] = photoPath
        }
        
        let event = createEventPayload(eventType: "extraction", watermarkData: watermarkData, metadata: metadata)
        sendEvent(event)
    }
    
    private func createEventPayload(eventType: String, watermarkData: String, metadata: [String: Any]) -> [String: Any] {
        let systemInfo = SystemInfo.getSystemInfo()
        
        var payload: [String: Any] = [
            "eventType": eventType,
            "watermarkData": watermarkData,
            "timestamp": Date().timeIntervalSince1970,
            "userId": SystemInfo.getUsername(),
            "username": SystemInfo.getUsername(),
            "computerName": SystemInfo.getComputerName(),
            "machineUUID": SystemInfo.getMachineUUID(),
            "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "hostname": ProcessInfo.processInfo.hostName
        ]
        
        payload["metadata"] = metadata
        
        return payload
    }
    
    private func sendEvent(_ event: [String: Any]) {
        let url = URL(string: "\(baseURL)/events")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = ProcessInfo.processInfo.environment["WALDO_API_KEY"] {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: event)
        } catch {
            print("Error serializing event data: \(error)")
            return
        }
        
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("API request failed: \(error.localizedDescription)")
                self?.queueForRetry(event: event)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
                self?.queueForRetry(event: event)
                return
            }
            
            if 200...299 ~= httpResponse.statusCode {
                print("✓ Event logged successfully: \(event["eventType"] ?? "unknown")")
                self?.processOfflineQueue()
            } else {
                print("API request failed with status: \(httpResponse.statusCode)")
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("Response: \(responseBody)")
                }
                self?.queueForRetry(event: event)
            }
        }.resume()
    }
    
    private func queueForRetry(event: [String: Any]) {
        offlineQueue.append((event: event, retryCount: 0))
        print("Event queued for retry. Queue size: \(offlineQueue.count)")
    }
    
    private func processOfflineQueue() {
        guard !offlineQueue.isEmpty else { return }
        
        let eventsToRetry = offlineQueue
        offlineQueue.removeAll()
        
        for queuedItem in eventsToRetry {
            if queuedItem.retryCount < maxRetries {
                let updatedItem = (event: queuedItem.event, retryCount: queuedItem.retryCount + 1)
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(updatedItem.retryCount) * 2.0) {
                    self.retryEvent(updatedItem)
                }
            } else {
                print("Max retries exceeded for event: \(queuedItem.event["eventType"] ?? "unknown")")
            }
        }
    }
    
    private func retryEvent(_ queuedItem: (event: [String: Any], retryCount: Int)) {
        let url = URL(string: "\(baseURL)/events")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = ProcessInfo.processInfo.environment["WALDO_API_KEY"] {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: queuedItem.event)
        } catch {
            print("Error serializing retry event data: \(error)")
            return
        }
        
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Retry attempt \(queuedItem.retryCount) failed: \(error.localizedDescription)")
                if queuedItem.retryCount < self?.maxRetries ?? 0 {
                    self?.offlineQueue.append(queuedItem)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                if queuedItem.retryCount < self?.maxRetries ?? 0 {
                    self?.offlineQueue.append(queuedItem)
                }
                return
            }
            
            if 200...299 ~= httpResponse.statusCode {
                print("✓ Retry successful for event: \(queuedItem.event["eventType"] ?? "unknown")")
            } else {
                print("Retry failed with status: \(httpResponse.statusCode)")
                if queuedItem.retryCount < self?.maxRetries ?? 0 {
                    self?.offlineQueue.append(queuedItem)
                }
            }
        }.resume()
    }
    
    func getQueueStatus() -> [String: Any] {
        return [
            "queuedEvents": offlineQueue.count,
            "baseURL": baseURL,
            "hasApiKey": ProcessInfo.processInfo.environment["WATERMARK_API_KEY"] != nil
        ]
    }
}