import ObjectiveC

// TODO: Make originalIMP non-optional

internal protocol HookStrategy: AnyObject, CustomDebugStringConvertible {
    
    var `class`: AnyClass { get }
    var scope: HookScope { get }
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
    
    /// Validates that the target method exists on the class, throwing if not found.
    internal func validate() throws {
        guard class_getInstanceMethod(self.class, self.selector) != nil else {
            throw InterposeError.methodNotFound(self.class, self.selector)
        }
    }
    
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
