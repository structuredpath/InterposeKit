import ObjectiveC

extension NSObject {
    
    @available(*, deprecated, renamed: "addHook(for:methodSignature:hookSignature:implementation:)")
    @discardableResult
    public func hook<MethodSignature, HookSignature> (
        _ selector: Selector,
        methodSignature: MethodSignature.Type = MethodSignature.self,
        hookSignature: HookSignature.Type = HookSignature.self,
        _ implementation: HookImplementationBuilder<MethodSignature, HookSignature>
    ) throws -> some Hook {
        precondition(
            !(self is AnyClass),
            "There should not be a way to cast an NSObject to AnyClass."
        )
        
        return try self.addHook(
            for: selector,
            methodSignature: methodSignature,
            hookSignature: hookSignature,
            implementation: implementation
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
        methodSignature: MethodSignature.Type = MethodSignature.self,
        hookSignature: HookSignature.Type = HookSignature.self,
        _ implementation: HookImplementationBuilder<MethodSignature, HookSignature>
    ) throws -> some Hook {
        let hook = try Interpose.ClassHook(
            class: self as AnyClass,
            selector: selector,
            implementation: implementation
        )
        try hook.apply()
        return hook
    }
    
}
