import ObjectiveC

extension NSObject {
    
    /// Installs a hook for the specified selector on this object instance.
    ///
    /// Replaces the implementation of an instance method with a block-based hook, while providing
    /// access to the original implementation through a proxy.
    ///
    /// To be hookable, the method must be exposed to the Objective-C runtime. When written
    /// in Swift, it must be marked `@objc dynamic`.
    ///
    /// - Parameters:
    ///   - selector: The selector of the instance method to hook.
    ///   - methodSignature: The expected C function type of the original method implementation.
    ///   - hookSignature: The type of the hook block.
    ///   - build: A hook builder closure that receives a proxy to the hook (enabling access
    ///     to the original implementation) and returns the hook block.
    ///
    /// - Returns: The installed hook, which can later be reverted by calling `try hook.revert()`.
    ///
    /// - Throws: An error if the hook could not be applied—for example, if the method
    ///   does not exist or is not exposed to the Objective-C runtime.
    ///
    /// ### Example
    /// ```swift
    /// let hook = try object.applyHook(
    ///     for: #selector(MyClass.someMethod),
    ///     methodSignature: (@convention(c) (NSObject, Selector, Int) -> Void).self,
    ///     hookSignature: (@convention(block) (NSObject, Int) -> Void).self
    /// ) { hook in
    ///     return { `self`, parameter in
    ///         hook.original(self, hook.selector, parameter)
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
        build: HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        let hook = try Hook(
            object: self,
            selector: selector,
            build: build
        )
        try hook.apply()
        return hook
    }
    
}
