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
    
    /// The flag that enables logging of InterposeKit internal operations to standard output
    /// using the `print(…)` function. Defaults to `false`.
    ///
    /// It is recommended to set this flag only once early in your application lifecycle,
    /// e.g. at app startup or in test setup.
    public nonisolated(unsafe) static var isLoggingEnabled = false
    
    internal nonisolated static func log(
        _ message: @autoclosure () -> String
    ) {
        if self.isLoggingEnabled {
            print("[InterposeKit] \(message())")
        }
    }
    
    internal nonisolated static func fail(
        _ message: @autoclosure () -> String
    ) -> Never {
        fatalError("[InterposeKit] \(message())")
    }
    
}
