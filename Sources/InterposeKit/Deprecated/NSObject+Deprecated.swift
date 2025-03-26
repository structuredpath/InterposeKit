import ObjectiveC

extension NSObject {
    
    @available(*, deprecated, renamed: "applyHook(for:methodSignature:hookSignature:build:)")
    @discardableResult
    public func addHook<MethodSignature, HookSignature>(
        for selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        implementation: HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        return try self.applyHook(
            for: selector,
            methodSignature: methodSignature,
            hookSignature: hookSignature,
            build: implementation
        )
    }
    
    @available(*, deprecated, renamed: "addHook(for:methodSignature:hookSignature:build:)")
    @discardableResult
    public func hook<MethodSignature, HookSignature> (
        _ selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ build: HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        precondition(
            !(self is AnyClass),
            "There should not be a way to cast an NSObject to AnyClass."
        )
        
        return try self.addHook(
            for: selector,
            methodSignature: methodSignature,
            hookSignature: hookSignature,
            implementation: build
        )
    }
    
    @available(*, deprecated, message: """
    Deprecated to avoid confusion: this hooks instance methods on classes, but can be mistaken \
    for hooking class methods, which is not supported. Use `Interpose(Class.self)` with \
    `prepareHook(…)` to make the intent explicit.
    """)
    @discardableResult
    public class func hook<MethodSignature, HookSignature> (
        _ selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ build: HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        let hook = try Hook(
            class: self as AnyClass,
            selector: selector,
            build: build
        )
        try hook.apply()
        return hook
    }
    
}
