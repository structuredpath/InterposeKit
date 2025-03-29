import Foundation

/// Interpose is a modern library to swizzle elegantly in Swift.
///
/// Methods are hooked via replacing the implementation, instead of the usual exchange.
/// Supports both swizzling classes and individual objects.
final public class Interpose {
    
    public init() {}
    
}

// MARK: Logging

extension Interpose {
    public static var isLoggingEnabled = false

    static func log(_ object: Any) {
        if isLoggingEnabled {
            print("[InterposeKit] \(object)")
        }
    }
    
    static func fail(_ message: String) -> Never {
        fatalError("[InterposeKit] \(message)")
    }
}
