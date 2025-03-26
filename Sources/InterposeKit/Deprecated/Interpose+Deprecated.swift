import Foundation

extension Interpose {
    
    @available(*, deprecated, message: "Use 'hook(_:methodSignature:hookSignature:_:)' instead and pass materialized selector.")
    @discardableResult
    public func hook<MethodSignature, HookSignature>(
        _ selectorName: String,
        methodSignature: MethodSignature.Type,
        hookSignature: HookSignature.Type,
        _ implementation: HookImplementationBuilder<MethodSignature, HookSignature>
    ) throws -> some Hook {
        try self.hook(
            NSSelectorFromString(selectorName),
            methodSignature: methodSignature,
            hookSignature: hookSignature,
            implementation
        )
    }
    
}
