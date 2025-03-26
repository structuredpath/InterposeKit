import ObjectiveC

internal protocol HookStrategy: AnyObject, CustomDebugStringConvertible {
    
    var `class`: AnyClass { get }
    var scope: HookScope { get }
    var selector: Selector { get }
    
    /// The implementation used to interpose the method, created during hook setup and used
    /// to replace the original implementation while the hook is applied.
    var hookIMP: IMP { get }
    
    /// The original implementation captured when the hook is applied, restored when the hook
    /// is reverted.
    var storedOriginalIMP: IMP? { get }
    
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
    
    /// Returns the original implementation of the hooked method.
    ///
    /// If the hook has been applied, the stored original implementation is returned.
    /// Otherwise, a dynamic lookup of the original implementation is performed using
    /// `lookUpIMP()`.
    ///
    /// Crashes if no implementation can be found, which should only occur if the class
    /// is in a funky state.
    internal var originalIMP: IMP {
        if let storedOriginalIMP = self.storedOriginalIMP {
            return storedOriginalIMP
        }
        
        if let originalIMP = self.lookUpIMP() {
            return originalIMP
        }
        
        fatalError()
    }
    
    /// Dynamically resolves the current implementation of the hooked method by walking the class
    /// hierarchy.
    ///
    /// This may return either the original or a hook implementation, depending on the state
    /// of the hook.
    ///
    /// Use `originalIMP` if you explicitly need the original implementation.
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
