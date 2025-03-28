import ObjectiveC

extension Interpose {
    
    @available(*, unavailable, message: "Use 'init(_ class: AnyClass)' followed by 'applyHook(…)' instead.")
    public convenience init(
        _ class: AnyClass,
        builder: (Interpose) throws -> Void
    ) throws {
        fatalError("Interpose(class:builder:) is unavailable.")
    }
    
    @available(*, deprecated, message: "Use 'hook(_:methodSignature:hookSignature:_:)' instead and pass materialized selector.")
    @discardableResult
    public func hook<MethodSignature, HookSignature>(
        _ selectorName: String,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ build: HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        try self.hook(
            Selector(selectorName),
            methodSignature: methodSignature,
            hookSignature: hookSignature,
            build
        )
    }
    
    @available(*, unavailable, message: "'apply()' is no longer supported. Use 'applyHook(…)' instead to apply individual hooks.")
    @discardableResult
    public func apply(_ builder: ((Interpose) throws -> Void)? = nil) throws -> Interpose {
        fatalError("Interpose.apply() is unavailable.")
    }
    
    @available(*, unavailable, message: "'revert()' is no longer supported. Keep a reference to the individual hooks and call 'revert()' on them.")
    @discardableResult
    public func revert(_ builder: ((Interpose) throws -> Void)? = nil) throws -> Interpose {
        fatalError("Interpose.revert() is unavailable.")
    }
        
}
