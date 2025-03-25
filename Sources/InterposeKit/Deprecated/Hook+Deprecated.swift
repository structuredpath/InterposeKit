extension AnyHook {
    
    @available(*, deprecated, renamed: "HookState", message: "Use top-level 'HookState'.")
    public typealias State = HookState
    
    @available(*, deprecated, message: "Use 'apply()' returning Void. The overload returning 'Self' has been removed.")
    @_disfavoredOverload
    public func apply() throws -> Self {
        try self.apply()
        return self
    }
    
    @available(*, deprecated, message: "Use 'revert()' returning Void. The overload returning 'Self' has been removed.")
    @_disfavoredOverload
    public func revert() throws -> Self {
        try revert()
        return self
    }
    
}

extension HookState {
    
    @available(*, deprecated, renamed: "pending", message: "Use 'pending' instead.")
    public static var prepared: Self { .pending }
    
    @available(*, deprecated, renamed: "active", message: "Use 'active' instead.")
    public static var interposed: Self { .active }
    
    @available(*, deprecated, renamed: "failed", message: """
    Use 'failed' instead. The state no longer carries an associated error—handle errors  where
    the hook is applied.
    """)
    public static var error: Self { .failed }
    
}
