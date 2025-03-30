import ObjectiveC

extension NSObject {
    
    @available(*, deprecated, renamed: "applyHook(for:methodSignature:hookSignature:build:)")
    @discardableResult
    public func hook<MethodSignature, HookSignature> (
        _ selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ build: @escaping HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        try self.applyHook(
            for: selector,
            methodSignature: methodSignature,
            hookSignature: hookSignature,
            build: build
        )
    }
    
    @available(
        *,
        deprecated,
        message: """
        Deprecated for clarity: this hooks instance methods on classes, but can be mistaken for \
        hooking class methods, which is not currently supported. Use 'Interpose.applyHook(…)' \
        and pass the class explicitly to avoid ambiguity.
        """
    )
    @discardableResult
    public class func hook<MethodSignature, HookSignature> (
        _ selector: Selector,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ build: @escaping HookBuilder<MethodSignature, HookSignature>
    ) throws -> Hook {
        let hook = try Hook(
            target: .class(self),
            selector: selector,
            build: build
        )
        try hook.apply()
        return hook
    }
    
}
