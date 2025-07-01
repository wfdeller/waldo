import Foundation

struct Logger {
    private let verbose: Bool
    private let debug: Bool
    
    init(verbose: Bool = false, debug: Bool = false) {
        self.verbose = verbose
        self.debug = debug
    }
    
    func verbose(_ message: String) {
        if verbose {
            print(message)
        }
    }
    
    func debug(_ message: String) {
        if debug {
            print("Debug: \(message)")
        }
    }
    
    func verboseWithPrefix(_ prefix: String, _ message: String) {
        if verbose {
            print("\(prefix)\(message)")
        }
    }
    
    func info(_ message: String) {
        print(message)
    }
    
    func error(_ message: String) {
        print("Error: \(message)")
    }
    
    func status(_ message: String, indent: Int = 0) {
        if verbose {
            let indentation = String(repeating: "  ", count: indent)
            print("\(indentation)\(message)")
        }
    }
    
    func progress(_ step: String, current: Int, total: Int) {
        if verbose {
            print("\(step) (\(current)/\(total))")
        }
    }
    
    func metric(_ name: String, value: Any) {
        if verbose {
            print("\(name): \(value)")
        }
    }
    
    func timing(_ operation: String, duration: TimeInterval) {
        if verbose {
            print("\(operation) completed in \(String(format: "%.2f", duration))s")
        }
    }
}