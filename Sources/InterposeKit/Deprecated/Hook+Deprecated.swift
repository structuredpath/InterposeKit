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
