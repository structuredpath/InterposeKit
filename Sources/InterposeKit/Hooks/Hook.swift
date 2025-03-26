import ObjectiveC

public typealias HookImplementationBuilder<MethodSignature, HookSignature> = (TypedHook<MethodSignature>) -> HookSignature

/// A runtime hook that interposes a single instance method on a class or object.
public protocol Hook: AnyObject {
    
    /// The class whose instance method is being interposed.
    var `class`: AnyClass { get }
    
    /// The selector identifying the instance method being interposed.
    var selector: Selector { get }
    
    /// The current state of the hook.
    var state: HookState { get }
    
    /// Applies the hook by interposing the method implementation.
    func apply() throws
    
    /// Reverts the hook, restoring the original method implementation.
    func revert() throws
    
    // TODO: Rename to `cleanUp()`
    func cleanup()
    
}

public enum HookState: Equatable {
    
    /// The hook is ready to be applied.
    case pending
    
    /// The hook has been successfully applied.
    case active
    
    /// The hook failed to apply.
    case failed
    
}
