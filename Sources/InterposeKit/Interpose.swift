import Foundation

/// Interpose is a modern library to swizzle elegantly in Swift.
///
/// Methods are hooked via replacing the implementation, instead of the usual exchange.
/// Supports both swizzling classes and individual objects.
final public class Interpose {
    /// Stores swizzle hooks and executes them at once.
    public let `class`: AnyClass
    /// Lists all hooks for the current interpose class object.
    public private(set) var hooks: [AnyHook] = []

    /// If Interposing is object-based, this is set.
    public let object: AnyObject?

    // Checks if a object is posing as a different class
    // via implementing 'class' and returning something else.
    private func checkObjectPosingAsDifferentClass(_ object: AnyObject) -> AnyClass? {
        let perceivedClass: AnyClass = type(of: object)
        let actualClass: AnyClass = object_getClass(object)!
        if actualClass != perceivedClass {
            return actualClass
        }
        return nil
    }

    // This is based on observation, there is no documented way
    private func isKVORuntimeGeneratedClass(_ klass: AnyClass) -> Bool {
        NSStringFromClass(klass).hasPrefix("NSKVO")
    }

    /// Initializes an instance of Interpose for a specific class.
    /// If `builder` is present, `apply()` is automatically called.
    public init(_ `class`: AnyClass, builder: ((Interpose) throws -> Void)? = nil) throws {
        self.class = `class`
        self.object = nil

        // Only apply if a builder is present
        if let builder = builder {
            try apply(builder)
        }
    }

    /// Initialize with a single object to interpose.
    public init(_ object: NSObject, builder: ((Interpose) throws -> Void)? = nil) throws {
        self.object = object
        self.class = type(of: object)

        if let actualClass = checkObjectPosingAsDifferentClass(object) {
            if isKVORuntimeGeneratedClass(actualClass) {
                throw InterposeError.keyValueObservationDetected(object)
            } else {
                throw InterposeError.objectPosingAsDifferentClass(object, actualClass: actualClass)
            }
        }

        // Only apply if a builder is present
        if let builder = builder {
            try apply(builder)
        }
    }

    deinit {
        hooks.forEach({ $0.cleanup() })
    }

    /// Hook an `@objc dynamic` instance method via selector  on the current class.
    @discardableResult
    public func hook<MethodSignature, HookSignature> (
        _ selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ implementation: HookImplementationBuilder<MethodSignature, HookSignature>
    ) throws -> some Hook {
        let hook = try prepareHook(selector, methodSignature: methodSignature,
                                   hookSignature: hookSignature, implementation)
        try hook.apply()
        return hook
    }

    /// Prepares a hook, but does not call apply immediately.
    @discardableResult
    public func prepareHook<MethodSignature, HookSignature> (
        _ selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ implementation: HookImplementationBuilder<MethodSignature, HookSignature>
    ) throws -> some Hook {
        var hook: AnyHook
        if let object = self.object {
            hook = try ObjectHook(object: object, selector: selector, implementation: implementation)
        } else {
            hook = try ClassHook(class: `class`, selector: selector, implementation: implementation)
        }
        hooks.append(hook)
        return hook
    }

    /// Apply all stored hooks.
    @discardableResult public func apply(_ hook: ((Interpose) throws -> Void)? = nil) throws -> Interpose {
        try execute(hook) { try $0.apply() }
    }

    /// Revert all stored hooks.
    @discardableResult public func revert(_ hook: ((Interpose) throws -> Void)? = nil) throws -> Interpose {
        try execute(hook, expectedState: .active) { try $0.revert() }
    }

    private func execute(_ task: ((Interpose) throws -> Void)? = nil,
                         expectedState: HookState = .pending,
                         executor: ((AnyHook) throws -> Void)) throws -> Interpose {
        // Run pre-apply code first
        if let task = task {
            try task(self)
        }
        // Validate all tasks, stop if anything is not valid
        guard hooks.allSatisfy({
            (try? $0.validate(expectedState: expectedState)) != nil
        }) else {
            throw InterposeError.invalidState(expectedState: expectedState)
        }
        // Execute all tasks
        try hooks.forEach(executor)
        return self
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
