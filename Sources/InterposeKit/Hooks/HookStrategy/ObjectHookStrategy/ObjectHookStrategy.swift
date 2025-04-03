import ITKSuperBuilder
import ObjectiveC

internal final class ObjectHookStrategy: HookStrategy {
    
    // ============================================================================ //
    // MARK: Initialization
    // ============================================================================ //
    
    internal init(
        object: NSObject,
        selector: Selector,
        makeHookIMP: @escaping () -> IMP
    ) {
        self.class = type(of: object)
        self.object = object
        self.selector = selector
        self.makeHookIMP = makeHookIMP
    }
    
    // ============================================================================ //
    // MARK: Configuration
    // ============================================================================ //
    
    internal let `class`: AnyClass
    internal let object: NSObject
    internal var scope: HookScope { .object(self.object) }
    internal let selector: Selector
    
    private let makeHookIMP: () -> IMP
    
    // ============================================================================ //
    // MARK: Implementations & Handle
    // ============================================================================ //
    
    private(set) internal var appliedHookIMP: IMP?
    private(set) internal var storedOriginalIMP: IMP?
    
    private lazy var handle = ObjectHookHandle(
        getOriginalIMP: { [weak self] in self?.storedOriginalIMP },
        setOriginalIMP: { [weak self] in self?.storedOriginalIMP = $0 }
    )

    // ============================================================================ //
    // MARK: Validation
    // ============================================================================ //
    
    internal func validate() throws {
        guard class_getInstanceMethod(self.class, self.selector) != nil else {
            throw InterposeError.methodNotFound(
                class: self.class,
                selector: self.selector
            )
        }
        
        let perceivedClass: AnyClass = type(of: self.object)
        let actualClass: AnyClass = object_getClass(self.object)
        
        if perceivedClass != actualClass {
            if object_isKVOActive(self.object) {
                throw InterposeError.kvoDetected(object: self.object)
            }
            
            if !ObjectSubclassManager.hasInstalledSubclass(self.object) {
                throw InterposeError.unexpectedDynamicSubclass(
                    object: self.object,
                    actualClass: actualClass
                )
            }
        }
    }
    
    // ============================================================================ //
    // MARK: Installing Implementation
    // ============================================================================ //
    
    internal func replaceImplementation() throws {
        let hookIMP = self.makeHookIMP()
        
        // Fetch the method, whose implementation we want to replace.
        guard let method = class_getInstanceMethod(self.class, self.selector) else {
            throw InterposeError.methodNotFound(
                class: self.class,
                selector: self.selector
            )
        }
        
        // Ensure that the method has an associated implementation.
        guard self.lookUpIMP() != nil else {
            throw InterposeError.implementationNotFound(
                class: self.class,
                selector: self.selector
            )
        }
        
        // Retrieve a ready-to-use dynamic subclass. It might be reused if the object already
        // has one installed or a newly created one.
        let subclass: AnyClass = try ObjectSubclassManager.ensureSubclassInstalled(for: self.object)
        
        // If the dynamic subclass does not implement the method directly, we create a super
        // trampoline first. Otherwise, when a hook for that method has already been applied
        // (and potentially reverted), we skip this step.
        if !class_implementsInstanceMethod(subclass, self.selector) {
            do {
                try ITKSuperBuilder.addSuperInstanceMethod(
                    to: subclass,
                    selector: self.selector
                )
                
                Interpose.log({
                    var message = "Added super trampoline for -[\(subclass) \(self.selector)]"
                    if let imp = class_getMethodImplementation(subclass, self.selector) {
                        message += " IMP: \(imp)"
                    }
                    return message
                }())
            } catch {
                throw InterposeError.failedToAddSuperTrampoline(
                    class: subclass,
                    selector: self.selector,
                    underlyingError: error as NSError
                )
            }
        }
        
        guard let imp = class_replaceMethod(subclass, self.selector, hookIMP, method_getTypeEncoding(method)) else {
            // This should not happen if the class implements the method or we have installed
            // the super trampoline. Instead, we should make the trampoline implementation
            // failable.
            throw InterposeError.implementationNotFound(
                class: subclass,
                selector: self.selector
            )
        }
        
        self.appliedHookIMP = hookIMP
        self.storedOriginalIMP = imp
        ObjectHookRegistry.register(self.handle, for: hookIMP)
        
        Interpose.log("Replaced implementation for -[\(self.class) \(self.selector)] IMP: \(self.storedOriginalIMP!) -> \(hookIMP)")
    }
    
    internal func restoreImplementation() throws {
        guard let hookIMP = self.appliedHookIMP else { return }
        guard let originalIMP = self.storedOriginalIMP else { return }
        
        defer {
            imp_removeBlock(hookIMP)
            self.appliedHookIMP = nil
            self.storedOriginalIMP = nil
        }
        
        guard let dynamicSubclass = ObjectSubclassManager.installedSubclass(
            for: self.object
        ) else { return }
        
        guard let method = class_getInstanceMethod(self.class, self.selector) else {
            throw InterposeError.methodNotFound(class: self.class, selector: self.selector)
        }
        
        guard let currentIMP = class_getMethodImplementation(dynamicSubclass, self.selector) else {
            // Do we need this???
            throw InterposeError.implementationNotFound(
                class: self.class,
                selector: self.selector
            )
        }
        
        // We are the topmost hook, replace method.
        if currentIMP == hookIMP {
            let previousIMP = class_replaceMethod(dynamicSubclass, self.selector, originalIMP, method_getTypeEncoding(method))
            guard previousIMP == hookIMP else {
                throw InterposeError.revertCorrupted(
                    class: dynamicSubclass,
                    selector: self.selector,
                    imp: previousIMP
                )
            }
            Interpose.log("Restored implementation for -[\(self.class) \(self.selector)] IMP: \(originalIMP)")
        } else {
            let nextHook = self._findParentHook(from: currentIMP)
            // Replace next's original IMP
            nextHook?.originalIMP = originalIMP
        }
        
        
        
        // FUTURE: remove class pair!
        // This might fail if we get KVO observed.
        // objc_disposeClassPair does not return a bool but logs if it fails.
        //
        // objc_disposeClassPair(dynamicSubclass)
        // self.dynamicSubclass = nil
    }
    
    // ============================================================================ //
    // MARK: Helpers
    // ============================================================================ //
    
    /// Traverses the object hook chain to find the handle to the parent of this hook, starting
    /// from the topmost IMP for the hooked method.
    ///
    /// This is used when removing an object hook to rewire the parent hook’s original IMP
    /// back to this hook’s original IMP, effectively unlinking it from the chain.
    ///
    /// - Parameter topmostIMP: The IMP of the topmost installed hook.
    /// - Returns: The handle to the parent hook in the chain, or `nil` if topmost.
    private func _findParentHook(from topmostIMP: IMP) -> ObjectHookHandle? {
        var currentIMP: IMP? = topmostIMP
        var previousHandle: ObjectHookHandle?
        
        while let imp = currentIMP {
            // Get the handle for the current IMP and stop if not found.
            guard let currentHandle = ObjectHookRegistry.handle(for: imp) else { break }
            
            // If we’ve reached this hook, the previous one is its parent.
            if currentHandle === self.handle { return previousHandle }
            
            previousHandle = currentHandle
            currentIMP = currentHandle.originalIMP
        }
        
        return nil
    }
    
}
