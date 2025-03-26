import ObjectiveC

protocol HookStrategy: AnyObject, CustomDebugStringConvertible {
    
    /// The replacement implementation used to interpose the method, created during hook setup.
    var replacementIMP: IMP { get }
    
    /// The original method implementation, captured when the hook is applied.
    var originalIMP: IMP? { get }
    
}
