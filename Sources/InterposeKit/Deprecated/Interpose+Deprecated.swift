import ObjectiveC

extension Interpose {
    
    @available(
        *,
        unavailable,
        message: "Use 'init(_ class: AnyClass)' followed by 'applyHook(…)' instead."
    )
    public convenience init(
        _ class: AnyClass,
        builder: (Interpose) throws -> Void
    ) throws {
        fatalError("Interpose(_:builder:) is unavailable.")
    }
    
    @available(
        *,
        unavailable,
        message: "Use 'init(_ object: NSObject)' followed by 'applyHook(…)' instead."
    )
    public convenience init(
        _ object: NSObject,
        builder: (Interpose) throws -> Void
    ) throws {
        fatalError("Interpose(_:builder:) is unavailable.")
    }
    
    @available(
        *,
        deprecated,
        message: """
        Use 'applyHook(for:methodSignature:hookSignature:_:)' instead and pass a materialized 
        selector.
        """
    )
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
    
    @available(
        *,
        deprecated,
        renamed: "applyHook(for:methodSignature:hookSignature:_:)",
        message: "Use 'applyHook(for:methodSignature:hookSignature:_:)' instead."
    )
    @discardableResult
    public func hook<MethodSignature, HookSignature> (
        _ selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ build: HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        try self.applyHook(
            for: selector,
            methodSignature: methodSignature,
            hookSignature: hookSignature,
            build
        )
    }
    
    @available(
        *,
        deprecated,
        renamed: "prepareHook(for:methodSignature:hookSignature:_:)",
        message: "Use 'prepareHook(for:methodSignature:hookSignature:_:)' instead."
    )
    @discardableResult
    public func prepareHook<MethodSignature, HookSignature> (
        _ selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ build: HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        try self.prepareHook(
            for: selector,
            methodSignature: methodSignature,
            hookSignature: hookSignature,
            build
        )
    }
    
    @available(
        *,
        unavailable,
        message: """
        'apply()' is no longer supported. Use 'applyHook(…)' instead to apply individual hooks.
        """
    )
    @discardableResult
    public func apply(_ builder: ((Interpose) throws -> Void)? = nil) throws -> Interpose {
        fatalError("Interpose.apply() is unavailable.")
    }
    
    @available(
        *,
        unavailable,
        message: """
        'revert()' is no longer supported. Keep a reference to the individual hooks and call 
        'revert()' on them.
        """
    )
    @discardableResult
    public func revert(_ builder: ((Interpose) throws -> Void)? = nil) throws -> Interpose {
        fatalError("Interpose.revert() is unavailable.")
    }
        
}
