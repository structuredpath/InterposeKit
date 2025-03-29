import ObjectiveC

extension Interpose {
    
    @available(
        *,
         unavailable,
         message: """
        The builder-based initializer pattern is no longer supported. Use the static method \
        'Interpose.applyHook(on:for:methodSignature:hookSignature:build:)' for immediate \
        installation, or 'Interpose.prepareHook(…)' for manual control.
        """
    )
    public convenience init(
        _ class: AnyClass,
        builder: (Interpose) throws -> Void
    ) throws {
        Interpose.fail("Unavailable API")
    }
    
    @available(
        *,
         unavailable,
         message: """
        The builder-based initializer pattern is no longer supported. Use the static method \
        'Interpose.applyHook(on:for:methodSignature:hookSignature:build:)' for immediate \
        installation, or 'Interpose.prepareHook(…)' for manual control.
        """
    )
    public convenience init(
        _ object: NSObject,
        builder: ((Interpose) throws -> Void)? = nil
    ) throws {
        Interpose.fail("Unavailable API")
    }
    
    @available(
        *,
         unavailable,
         message: """
        Instance method 'hook(_:methodSignature:hookSignature:_:)' is no longer supported. \
        Use 'Interpose.applyHook(on:for:methodSignature:hookSignature:build:)' instead.
        """
    )
    @discardableResult
    public func hook<MethodSignature, HookSignature>(
        _ selectorName: String,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ build: @escaping HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        Interpose.fail("Unavailable API")
    }
    
    @available(
        *,
         unavailable,
         message: """
        Instance method 'hook(_:methodSignature:hookSignature:_:)' is no longer supported. \
        Use 'Interpose.applyHook(on:for:methodSignature:hookSignature:build:)' instead.
        """
    )
    @discardableResult
    public func hook<MethodSignature, HookSignature>(
        _ selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ build: @escaping HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        Interpose.fail("Unavailable API")
    }
    
    @available(
        *,
         unavailable,
         message: """
        Instance method 'prepareHook(_:methodSignature:hookSignature:_:)' is no longer supported. \
        Use 'Interpose.prepareHook(on:for:methodSignature:hookSignature:build:)' instead.
        """
    )
    public func prepareHook<MethodSignature, HookSignature>(
        _ selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ build: @escaping HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        Interpose.fail("Unavailable API")
    }
    
    @available(
        *,
         unavailable,
         message: """
        'apply()' is no longer supported. Use 'Interpose.applyHook(…)' to apply individual hooks \
        directly using the new static API.
        """
    )
    @discardableResult
    public func apply(_ builder: ((Interpose) throws -> Void)? = nil) throws -> Interpose {
        Interpose.fail("Unavailable API")
    }
    
    @available(
        *,
         unavailable,
         message: """
        'revert()' is no longer supported. Keep a reference to each individual hook and call \
        'revert()' on them directly.
        """
    )
    @discardableResult
    public func revert(_ builder: ((Interpose) throws -> Void)? = nil) throws -> Interpose {
        Interpose.fail("Unavailable API")
    }
    
}
