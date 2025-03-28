import ObjectiveC

public final class __Interpose {

    // ============================================================================ //
    // MARK: Initialization
    // ============================================================================ //
    
    public init(class: AnyClass) {
        self.target = .class(`class`)
    }
    
    public init(object: AnyObject) {
        self.target = .object(object)
    }
    
    // ============================================================================ //
    // MARK: Configuration
    // ============================================================================ //
    
    /// The target of the hooks created via this factory.
    private let target: HookTarget
    
    // ============================================================================ //
    // MARK: Hook Creation
    // ============================================================================ //
    
    /// Creates and returns a hook in pending state.
    public func prepareHook<MethodSignature, HookSignature>(
        for selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        build: HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        return try Hook(
            target: self.target,
            selector: selector,
            build: build
        )
    }
    
    /// Creates a hook, applies it, and returns it in one go.
    @discardableResult
    public func applyHook<MethodSignature, HookSignature>(
        for selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        build: HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        let hook = try Hook(
            target: self.target,
            selector: selector,
            build: build
        )
        try hook.apply()
        return hook
    }
    
}
