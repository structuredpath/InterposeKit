import InterposeKitObjC
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
        // Ensure that the method exists.
        guard class_getInstanceMethod(self.class, self.selector) != nil else {
            throw InterposeError.methodNotFound(
                class: self.class,
                kind: .instance,
                selector: self.selector
            )
        }
        
        // Ensure that the method has an associated implementation (can be in a superclass).
        guard self.lookUpIMP() != nil else {
            throw InterposeError.implementationNotFound(
                class: self.class,
                kind: .instance,
                selector: self.selector
            )
        }
        
        // Ensure that the object either does not have a dynamic subclass installed or that
        // it is the subclass installed by InterposeKit rather than by KVO or other mechanism.
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
                kind: .instance,
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
        
        guard let originalIMP = class_replaceMethod(
            subclass,
            self.selector,
            hookIMP,
            method_getTypeEncoding(method)
        ) else {
            // This should not fail under normal circumstances, as the subclass should already
            // have an associated implementation, which might be the just-installed trampoline
            // or an existing hook.
            throw InterposeError.implementationNotFound(
                class: subclass,
                kind: .instance,
                selector: self.selector
            )
        }
        
        self.appliedHookIMP = hookIMP
        self.storedOriginalIMP = originalIMP
        
        self.object.incrementHookCount()
        ObjectHookRegistry.register(self.handle, for: hookIMP)
        
        Interpose.log("Replaced implementation for -[\(self.class) \(self.selector)] IMP: \(originalIMP) -> \(hookIMP)")
    }
    
    internal func restoreImplementation() throws {
        if object_isKVOActive(self.object) {
            throw InterposeError.kvoDetected(object: self.object)
        }
        
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
            throw InterposeError.methodNotFound(
                class: self.class,
                kind: .instance,
                selector: self.selector
            )
        }
        
        guard let currentIMP = class_getMethodImplementation(dynamicSubclass, self.selector) else {
            throw InterposeError.implementationNotFound(
                class: self.class,
                kind: .instance,
                selector: self.selector
            )
        }
        
        // If we are the topmost hook, we have to replace the implementation on the subclass.
        if currentIMP == hookIMP {
            let previousIMP = class_replaceMethod(
                dynamicSubclass,
                self.selector,
                originalIMP,
                method_getTypeEncoding(method)
            )
            
            guard previousIMP == hookIMP else {
                throw InterposeError.revertCorrupted(
                    class: dynamicSubclass,
                    kind: .instance,
                    selector: self.selector,
                    imp: previousIMP
                )
            }
        } else {
            // Otherwise, find the next hook and set its original IMP to this hook’s original IMP,
            // effectively unlinking this hook from the chain.
            let nextHook = self._findParentHook(from: currentIMP)
            nextHook?.originalIMP = originalIMP
        }
        
        Interpose.log("Restored implementation for -[\(self.class) \(self.selector)] IMP: \(originalIMP)")
        
        // Decrement the hook count and if this was the last hook, uninstall the dynamic subclass.
        if self.object.decrementHookCount() {
            ObjectSubclassManager.uninstallSubclass(for: object)
        }
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

extension NSObject {
    
    /// Increments the number of active object-based hooks on this instance by one.
    fileprivate func incrementHookCount() {
        self.hookCount += 1
    }
    
    /// Decrements the number of active object-based hooks on this instance by one and returns
    /// `true` if this was the last hook, or `false` otherwise.
    fileprivate func decrementHookCount() -> Bool {
        guard self.hookCount > 0 else { return false }
        self.hookCount -= 1
        return self.hookCount == 0
    }
    
    /// The current number of active object-based hooks on this instance.
    ///
    /// Internally stored using associated objects. Always returns a non-negative value.
    private var hookCount: Int {
        get {
            guard let count = objc_getAssociatedObject(
                self,
                &ObjectHookCountKey
            ) as? NSNumber else { return 0 }
            
            return count.intValue
        }
        set {
            let newCount = max(0, newValue)
            if newCount == 0 {
                objc_setAssociatedObject(
                    self,
                    &ObjectHookCountKey,
                    nil,
                    .OBJC_ASSOCIATION_ASSIGN
                )
            } else {
                objc_setAssociatedObject(
                    self,
                    &ObjectHookCountKey,
                    NSNumber(value: newCount),
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
        }
    }
    
}

#if compiler(>=5.10)
fileprivate nonisolated(unsafe) var ObjectHookCountKey: UInt8 = 0
#else
fileprivate var ObjectHookCountKey: UInt8 = 0
#endif
