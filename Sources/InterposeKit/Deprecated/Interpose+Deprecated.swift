import ObjectiveC

extension Interpose {
    
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
    
}
