public enum HookState: Equatable {
    
    /// The hook is ready to be applied.
    case pending
    
    /// The hook has been successfully applied.
    case active
    
    /// The hook failed to apply.
    case failed
    
}
