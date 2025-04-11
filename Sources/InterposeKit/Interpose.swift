#if !(arch(arm64) || arch(x86_64))
#error("[InterposeKit] This code only supports arm64 and x86_64 architectures.")
#endif

import ObjectiveC

/// Interpose is a modern library to swizzle elegantly in Swift.
public enum Interpose {
    
    // ============================================================================ //
    // MARK: Class Hooks
    // ============================================================================ //
    
    /// Prepares a hook for the specified method on a class.
    ///
    /// Builds a block-based hook for an instance or class method available to the Objective-C
    /// runtime, with access to the original implementation.
    ///
    /// The hook is returned in a pending state and must be applied using `apply()` to take effect.
    /// It can later be reverted using `revert()`.
    ///
    /// - Parameters:
    ///   - class: The class on which the method is defined.
    ///   - selector: The selector of the method to hook.
    ///   - methodKind: Whether the method is an instance or class method. Defaults to `.instance`.
    ///   - methodSignature: The expected C function type of the original method implementation.
    ///   - hookSignature: The type of the hook block.
    ///   - build: A closure that receives a proxy to the hook and returns the hook block.
    ///
    /// - Returns: The prepared hook instance in the pending state.
    ///
    /// - Throws: An ``InterposeError`` if the hook could not be prepared.
    ///
    /// ### Example
    ///
    /// ```swift
    /// let hook = try Interpose.prepareHook(
    ///     on: MyClass.self,
    ///     for: #selector(MyClass.getValue),
    ///     methodSignature: (@convention(c) (MyClass, Selector) -> Int).self,
    ///     hookSignature: (@convention(block) (MyClass) -> Int).self
    /// ) { hook in
    ///     return { `self` in
    ///         print("Before")
    ///         let value = hook.original(self, hook.selector)
    ///         print("After")
    ///         return value + 1
    ///     }
    /// }
    ///
    /// try hook.apply()
    /// try hook.revert()
    /// ```
    public static func prepareHook<MethodSignature, HookSignature>(
        on `class`: AnyClass,
        for selector: Selector,
        methodKind: MethodKind = .instance,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        build: @escaping HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        try Hook(
            target: .class(`class`, methodKind),
            selector: selector,
            build: build
        )
    }
    
    /// Applies a hook for the specified method on a class.
    ///
    /// Builds a block-based hook for an instance or class method available to the Objective-C
    /// runtime, with access to the original implementation.
    ///
    /// The hook takes effect immediately and can later be reverted using `revert()`.
    ///
    /// - Parameters:
    ///   - class: The class on which the method is defined.
    ///   - selector: The selector of the method to hook.
    ///   - methodKind: Whether the method is an instance or class method. Defaults to `.instance`.
    ///   - methodSignature: The expected C function type of the original method implementation.
    ///   - hookSignature: The type of the hook block.
    ///   - build: A closure that receives a proxy to the hook and returns the hook block.
    ///
    /// - Returns: The applied hook instance in the active state.
    ///
    /// - Throws: An ``InterposeError`` if the hook could not be applied.
    ///
    /// ### Example
    /// 
    /// ```swift
    /// let hook = try Interpose.applyHook(
    ///     on: MyClass.self,
    ///     for: #selector(MyClass.getValue),
    ///     methodSignature: (@convention(c) (MyClass, Selector) -> Int).self,
    ///     hookSignature: (@convention(block) (MyClass) -> Int).self
    /// ) { hook in
    ///     return { `self` in
    ///         print("Before")
    ///         let value = hook.original(self, hook.selector)
    ///         print("After")
    ///         return value + 1
    ///     }
    /// }
    ///
    /// try hook.revert()
    /// ```
    @discardableResult
    public static func applyHook<MethodSignature, HookSignature>(
        on `class`: AnyClass,
        for selector: Selector,
        methodKind: MethodKind = .instance,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        build: @escaping HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        let hook = try prepareHook(
            on: `class`,
            for: selector,
            methodKind: methodKind,
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
    
    /// Prepares a hook for the specified method on an object.
    ///
    /// Builds a block-based hook for an instance method available to the Objective-C runtime,
    /// with access to the original implementation.
    ///
    /// The hook is returned in a pending state and must be applied using `apply()` to take effect.
    /// It can then be reverted using `revert()`.
    ///
    /// InterposeKit installs the hook by creating a dynamic subclass at runtime and assigning it
    /// to the object. This ensures the hook only affects this specific object and leaves all other
    /// instances unchanged.
    ///
    /// - Parameters:
    ///   - object: The object on which to hook the method.
    ///   - selector: The selector of the method to hook.
    ///   - methodSignature: The expected C function type of the original method implementation.
    ///   - hookSignature: The type of the hook block.
    ///   - build: A closure that receives a proxy to the hook and returns the hook block.
    ///
    /// - Returns: The prepared hook instance in the pending state.
    ///
    /// - Throws: An ``InterposeError`` if the hook could not be prepared.
    ///
    /// ### Example
    ///
    /// ```swift
    /// let object = MyClass()
    /// let hook = try Interpose.prepareHook(
    ///     on: object,
    ///     for: #selector(MyClass.getValue),
    ///     methodSignature: (@convention(c) (MyClass, Selector) -> Int).self,
    ///     hookSignature: (@convention(block) (MyClass) -> Int).self
    /// ) { hook in
    ///     return { `self` in
    ///         print("Before")
    ///         let value = hook.original(self, hook.selector)
    ///         print("After")
    ///         return value + 1
    ///     }
    /// }
    ///
    /// try hook.apply()
    /// try hook.revert()
    /// ```
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
    
    /// Applies a hook for the specified method on an object.
    ///
    /// Builds a block-based hook for an instance method available to the Objective-C runtime,
    /// with access to the original implementation.
    ///
    /// The hook takes effect immediately and can later be reverted using `revert()`.
    ///
    /// InterposeKit installs the hook by creating a dynamic subclass at runtime and assigning it
    /// to the object. This ensures the hook only affects this specific object and leaves all other
    /// instances unchanged.
    ///
    /// - Parameters:
    ///   - object: The object on which to hook the method.
    ///   - selector: The selector of the method to hook.
    ///   - methodSignature: The expected C function type of the original method implementation.
    ///   - hookSignature: The type of the hook block.
    ///   - build: A closure that receives a proxy to the hook and returns the hook block.
    ///
    /// - Returns: The applied hook instance in the active state.
    ///
    /// - Throws: An ``InterposeError`` if the hook could not be applied.
    ///
    /// ### Example
    ///
    /// ```swift
    /// let object = MyClass()
    /// let hook = try Interpose.applyHook(
    ///     on: object,
    ///     for: #selector(MyClass.getValue),
    ///     methodSignature: (@convention(c) (MyClass, Selector) -> Int).self,
    ///     hookSignature: (@convention(block) (MyClass) -> Int).self
    /// ) { hook in
    ///     return { `self` in
    ///         print("Before")
    ///         let value = hook.original(self, hook.selector)
    ///         print("After")
    ///         return value + 1
    ///     }
    /// }
    ///
    /// try hook.revert()
    /// ```
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
    
    #if compiler(>=5.10)
    /// The flag that enables logging of InterposeKit internal operations to standard output
    /// using the `print(…)` function. Defaults to `false`.
    ///
    /// It is recommended to set this flag only once early in your application lifecycle,
    /// e.g. at app startup or in test setup.
    public nonisolated(unsafe) static var isLoggingEnabled = false
    #else
    public static var isLoggingEnabled = false
    #endif
    
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
