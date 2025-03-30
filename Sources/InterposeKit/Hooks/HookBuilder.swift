/// A closure that builds a hook implementation block for a method.
///
/// Receives a proxy to the hook, which provides access to the selector and the original
/// implementation, and returns a block to be installed when the hook is applied.
///
/// `MethodSignature` is the C function type of the original method implementation, typically
/// in the form: `(@convention(c) (NSObject, Selector, Params…) -> ReturnValue).self`.
///
/// `HookSignature` is the block type used as the replacement, typically in the form:
/// `(@convention(block) (NSObject, Params…) -> ReturnValue).self`.
public typealias HookBuilder<MethodSignature, HookSignature> = (HookProxy<MethodSignature>) -> HookSignature
