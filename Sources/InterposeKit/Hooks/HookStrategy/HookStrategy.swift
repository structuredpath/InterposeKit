import ObjectiveC

internal protocol HookStrategy: AnyObject, CustomDebugStringConvertible {
    
    var `class`: AnyClass { get }
    var scope: HookScope { get }
    var selector: Selector { get }

    /// Validates the target and throws if invalid.
    func validate() throws
    
    func replaceImplementation() throws
    func restoreImplementation() throws
    
    /// The current implementation used to interpose the method, created lazily when applying
    /// the hook and removed when the hook is reverted.
    var appliedHookIMP: IMP? { get }
    
    /// The original implementation captured when the hook is applied, restored when the hook
    /// is reverted.
    var storedOriginalIMP: IMP? { get }
    
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
        
        fatalError(
            """
            No original implementation found for selector \(self.selector) on \(self.class). \
            This likely  indicates a corrupted or misconfigured class.
            """
        )
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
