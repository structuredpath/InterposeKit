import ObjectiveC

// TODO: Make originalIMP non-optional

protocol HookStrategy: AnyObject, CustomDebugStringConvertible {
    
    /// The implementation used to interpose the method, created during hook setup and used
    /// to replace the original implementation while the hook is applied.
    var hookIMP: IMP { get }
    
    /// The original method implementation active before the hook is applied, restored when
    /// the hook is reverted.
    var originalIMP: IMP? { get }
    
}
