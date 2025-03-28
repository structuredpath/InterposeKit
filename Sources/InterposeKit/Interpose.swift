import Foundation

/// Interpose is a modern library to swizzle elegantly in Swift.
///
/// Methods are hooked via replacing the implementation, instead of the usual exchange.
/// Supports both swizzling classes and individual objects.
final public class Interpose {
    /// Stores swizzle hooks and executes them at once.
    public let `class`: AnyClass
    /// Lists all hooks for the current interpose class object.
    public private(set) var hooks: [Hook] = []

    /// If Interposing is object-based, this is set.
    public let object: NSObject?

    /// Initializes an instance of Interpose for a specific class.
    public init(_ `class`: AnyClass) {
        self.class = `class`
        self.object = nil
    }

    /// Initialize with a single object to interpose.
    public init(_ object: NSObject) throws {
        self.object = object
        self.class = type(of: object)
    }

    deinit {
        hooks.forEach({ $0.cleanup() })
    }

    /// Hook an `@objc dynamic` instance method via selector  on the current class.
    @discardableResult
    public func applyHook<MethodSignature, HookSignature> (
        for selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ build: HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        let hook = try self.prepareHook(
            for: selector,
            methodSignature: methodSignature,
            hookSignature: hookSignature,
            build
        )
        try hook.apply()
        return hook
    }

    /// Prepares a hook, but does not call apply immediately.
    @discardableResult
    public func prepareHook<MethodSignature, HookSignature> (
        for selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ build: HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        var hook: Hook
        if let object = self.object {
            hook = try Hook(target: .object(object), selector: selector, build: build)
        } else {
            hook = try Hook(target: .class(`class`), selector: selector, build: build)
        }
        hooks.append(hook)
        return hook
    }
}

// MARK: Logging

extension Interpose {
    /// Logging uses print and is minimal.
    public static var isLoggingEnabled = false

    /// Simple log wrapper for print.
    class func log(_ object: Any) {
        if isLoggingEnabled {
            print("[Interposer] \(object)")
        }
    }
}
