import ObjectiveC

extension NSObject {

    /// Prepares a hook for the specified method on this object.
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
    ///   - selector: The selector of the method to hook.
    ///   - methodSignature: The expected type of the original Objective-C method, declared using
    ///     `@convention(c)`. The function must take the receiving object and selector as its first
    ///     two parameters, e.g. `(@convention(c) (Receiver, Selector, Parameter) -> ReturnValue).self`.
    ///   - hookSignature: The expected type of the hook block, declared using `@convention(block)`.
    ///     It must match the method signature, excluding the `Selector` parameter, e.g.
    ///     `(@convention(block) (Receiver, Parameter) -> ReturnValue).self`.
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
    /// let hook = try object.prepareHook(
    ///     for: #selector(MyClass.getValue),
    ///     methodSignature: (@convention(c) (MyClass, Selector) -> Int).self,
    ///     hookSignature: (@convention(block) (MyClass) -> Int).self
    /// ) { hook in
    ///     return { `self` in
    ///         print("Before")
    ///         let result = hook.original(self, hook.selector)
    ///         print("After")
    ///         return result + 1
    ///     }
    /// }
    ///
    /// try hook.apply()
    /// try hook.revert()
    /// ```
    public func prepareHook<MethodSignature, HookSignature>(
        for selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        build: @escaping HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        return try Interpose.prepareHook(
            on: self,
            for: selector,
            methodSignature: methodSignature,
            hookSignature: hookSignature,
            build: build
        )
    }
    
    /// Applies a hook for the specified method on this object.
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
    ///   - selector: The selector of the method to hook.
    ///   - methodSignature: The expected type of the original Objective-C method, declared using
    ///     `@convention(c)`. The function must take the receiving object and selector as its first
    ///     two parameters, e.g. `(@convention(c) (Receiver, Selector, Parameter) -> ReturnValue).self`.
    ///   - hookSignature: The expected type of the hook block, declared using `@convention(block)`.
    ///     It must match the method signature, excluding the `Selector` parameter, e.g.
    ///     `(@convention(block) (Receiver, Parameter) -> ReturnValue).self`.
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
    /// let hook = try object.applyHook(
    ///     for: #selector(MyClass.getValue),
    ///     methodSignature: (@convention(c) (MyClass, Selector) -> Int).self,
    ///     hookSignature: (@convention(block) (MyClass) -> Int).self
    /// ) { hook in
    ///     return { `self` in
    ///         print("Before")
    ///         let result = hook.original(self, hook.selector)
    ///         print("After")
    ///         return result + 1
    ///     }
    /// }
    ///
    /// try hook.revert()
    /// ```
    @discardableResult
    public func applyHook<MethodSignature, HookSignature>(
        for selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        build: @escaping HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        try Interpose.applyHook(
            on: self,
            for: selector,
            methodSignature: methodSignature,
            hookSignature: hookSignature,
            build: build
        )
    }
    
}
