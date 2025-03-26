import ObjectiveC

// TODO: Make originalIMP non-optional

internal protocol HookStrategy: AnyObject, CustomDebugStringConvertible {
    
    /// The class whose instance method is being interposed.
    var `class`: AnyClass { get }
    
    /// /// The selector identifying the instance method being interposed.
    var selector: Selector { get }
    
    /// The implementation used to interpose the method, created during hook setup and used
    /// to replace the original implementation while the hook is applied.
    var hookIMP: IMP { get }
    
    /// The original method implementation active before the hook is applied, restored when
    /// the hook is reverted.
    var originalIMP: IMP? { get }
    
    func replaceImplementation() throws
    
    func restoreImplementation() throws
    
}

extension HookStrategy {
    
    /// Dynamically resolves the current IMP of the hooked method by walking the class hierarchy.
    /// This may return either the original or a hook IMP, depending on the state of the hook.
    internal func lookUpIMP() -> IMP? {
        var currentClass: AnyClass? = self.class
        
        while let `class` = currentClass {
            if let method = class_getInstanceMethod(`class`, self.selector) {
                return method_getImplementation(method)
            } else {
                currentClass = class_getSuperclass(currentClass)
            }
        }
        
        return nil
    }
    
}
