#if !(arch(arm64) || arch(x86_64))
#error("[InterposeKit] This code only supports arm64 and x86_64 architectures.")
#endif

import ObjectiveC

/// Interpose is a modern library to swizzle elegantly in Swift.
public enum Interpose {
    
    // ============================================================================ //
    // MARK: Class Hooks
    // ============================================================================ //
    
    public static func prepareHook<MethodSignature, HookSignature>(
        on `class`: AnyClass,
        for selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        build: @escaping HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        try Hook(
            target: .class(`class`),
            selector: selector,
            build: build
        )
    }
    
    @discardableResult
    public static func applyHook<MethodSignature, HookSignature>(
        on `class`: AnyClass,
        for selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        build: @escaping HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        let hook = try prepareHook(
            on: `class`,
            for: selector,
            methodSignature: methodSignature,
            hookSignature: hookSignature,
            build: build
        )
        try hook.apply()
        return hook
    }
    
    // ============================================================================ //
    // MARK: Object Hooks
    // ============================================================================ //
    
    public static func prepareHook<MethodSignature, HookSignature>(
        on object: NSObject,
        for selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        build: @escaping HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        try Hook(
            target: .object(object),
            selector: selector,
            build: build
        )
    }
    
    @discardableResult
    public static func applyHook<MethodSignature, HookSignature>(
        on object: NSObject,
        for selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        build: @escaping HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        let hook = try prepareHook(
            on: object,
            for: selector,
            methodSignature: methodSignature,
            hookSignature: hookSignature,
            build: build
        )
        try hook.apply()
        return hook
    }
    
    // ============================================================================ //
    // MARK: Logging
    // ============================================================================ //
    
    /// The flag indicating whether logging is enabled.
    public static var isLoggingEnabled = false
    
    internal static func log(_ message: String) {
        if self.isLoggingEnabled {
            print("[InterposeKit] \(message)")
        }
    }
    
    internal static func fail(_ message: String) -> Never {
        fatalError("[InterposeKit] \(message)")
    }
    
}
