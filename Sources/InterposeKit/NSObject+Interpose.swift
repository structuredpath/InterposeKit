import ObjectiveC

extension NSObject {
    
    /// Installs a hook for the specified Objective-C selector on this object instance.
    ///
    /// This method replaces the implementation of an Objective-C instance method with
    /// a block-based implementation, while optionally allowing access to the original
    /// implementation.
    ///
    /// To be hookable, the method must be exposed to the Objective-C runtime. When written
    /// in Swift, it must be marked `@objc dynamic`.
    ///
    /// - Parameters:
    ///   - selector: The selector of the instance method to hook.
    ///   - methodSignature: The expected C function type of the original method implementation.
    ///   - hookSignature: The type of the replacement block.
    ///   - implementation: A closure that receives a `TypedHook` and returns the replacement
    ///     implementation block.
    ///
    /// - Returns: The installed hook, allowing to remove the hook later by calling `hook.revert()`.
    ///
    /// - Throws: An error if the hook could not be applied, such as if the method does not exist
    ///   or is not implemented in Objective-C.
    ///
    /// ### Example
    ///
    /// ```swift
    /// let hook = try object.addHook(
    ///     for: #selector(MyClass.someMethod),
    ///     methodSignature: (@convention(c) (NSObject, Selector, Int) -> Void).self,
    ///     hookSignature: (@convention(block) (NSObject, Int) -> Void).self
    /// ) { hook in
    ///     return { `self`, parameter in
    ///         hook.original(self, hook.selector, parameter)
    ///     }
    /// }
    ///
    /// hook.revert()
    /// ```
    @discardableResult
    public func addHook<MethodSignature, HookSignature>(
        for selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        implementation: (TypedHook<MethodSignature, HookSignature>) -> HookSignature
    ) throws -> some Hook {
        let hook = try Interpose.ObjectHook(
            object: self,
            selector: selector,
            implementation: implementation
        )
        try hook.apply()
        return hook
    }
    
}
