import Foundation
import ITKSuperBuilder

final class ObjectHookStrategy: HookStrategy {
    
    init(
        object: NSObject,
        selector: Selector,
        makeHookIMP: @escaping () -> IMP
    ) {
        self.class = type(of: object)
        self.object = object
        self.selector = selector
        self.makeHookIMP = makeHookIMP
    }
    
    let `class`: AnyClass
    let object: NSObject
    var scope: HookScope { .object(self.object) }
    let selector: Selector
    
    private let makeHookIMP: () -> IMP
    private(set) var appliedHookIMP: IMP?
    private(set) var storedOriginalIMP: IMP?
    
    private lazy var handle = ObjectHookHandle(
        getOriginalIMP: { [weak self] in self?.storedOriginalIMP },
        setOriginalIMP: { [weak self] in self?.storedOriginalIMP = $0 }
    )
    
    /// Subclass that we create on the fly
    
    func validate() throws {
        guard class_getInstanceMethod(self.class, self.selector) != nil else {
            throw InterposeError.methodNotFound(class: self.class, selector: self.selector)
        }
        
        if let _ = checkObjectPosingAsDifferentClass(self.object) {
            if object_isKVOActive(self.object) {
                throw InterposeError.kvoDetected(object)
            }
            // TODO: Handle the case where the object is posing as different class but not the interpose subclass
        }
    }
    
    func replaceImplementation() throws {
        let hookIMP = self.makeHookIMP()
        self.appliedHookIMP = hookIMP
        ObjectHookRegistry.register(self.handle, for: hookIMP)
        
        guard let method = class_getInstanceMethod(self.class, self.selector) else {
            throw InterposeError.methodNotFound(class: self.class, selector: self.selector)
        }
        
        // The implementation of the call that is hooked must exist.
        guard self.lookUpIMP() != nil else {
            throw InterposeError.implementationNotFound(
                class: self.class,
                selector: self.selector
            )
        }
        
        // Check if there's an existing subclass we can reuse.
        // Create one at runtime if there is none.
        let dynamicSubclass: AnyClass = try InterposeSubclass.getDynamicSubclass(for: self.object)
        
        //  This function searches superclasses for implementations
        let classImplementsMethod = class_implementsInstanceMethod(dynamicSubclass, self.selector)
        let encoding = method_getTypeEncoding(method)
        
        // If the subclass is empty, we create a super trampoline first.
        // If a hook already exists, we must skip this.
        if !classImplementsMethod {
            do {
                try ITKSuperBuilder.addSuperInstanceMethod(to: dynamicSubclass, selector: self.selector)
                let imp = class_getMethodImplementation(dynamicSubclass, self.selector)!
                Interpose.log("Added super trampoline for -[\(dynamicSubclass) \(self.selector)]: \(imp)")
            } catch {
                // Interpose.log("Failed to add super implementation to -[\(dynamicClass).\(selector)]: \(error)")
                throw InterposeError.unknownError(String(describing: error))
            }
        }
        
        // Replace IMP (by now we guarantee that it exists)
        self.storedOriginalIMP = class_replaceMethod(dynamicSubclass, self.selector, hookIMP, encoding)
        guard self.storedOriginalIMP != nil else {
            // This should not happen if the class implements the method or we have installed
            // the super trampoline. Instead, we should make the trampoline implementation
            // failable.
            throw InterposeError.implementationNotFound(
                class: dynamicSubclass,
                selector: self.selector
            )
        }
        Interpose.log("Added -[\(self.class).\(self.selector)] IMP: \(self.storedOriginalIMP!) -> \(hookIMP)")
    }
    
    func restoreImplementation() throws {
        guard let hookIMP = self.appliedHookIMP else { return }
        guard let originalIMP = self.storedOriginalIMP else { return }
        
        defer {
            imp_removeBlock(hookIMP)
            self.appliedHookIMP = nil
            self.storedOriginalIMP = nil
        }
        
        guard let dynamicSubclass = InterposeSubclass.getExistingSubclass(object: self.object) else { return }
        
        guard let method = class_getInstanceMethod(self.class, self.selector) else {
            throw InterposeError.methodNotFound(class: self.class, selector: self.selector)
        }
        
        guard let currentIMP = class_getMethodImplementation(dynamicSubclass, self.selector) else {
            throw InterposeError.unknownError("No Implementation found")
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
            Interpose.log("Restored -[\(self.class).\(self.selector)] IMP: \(originalIMP)")
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
    
    // Checks if a object is posing as a different class
    // via implementing 'class' and returning something else.
    private func checkObjectPosingAsDifferentClass(_ object: AnyObject) -> AnyClass? {
        let perceivedClass: AnyClass = type(of: object)
        let actualClass: AnyClass = object_getClass(object)!
        if actualClass != perceivedClass {
            return actualClass
        }
        return nil
    }
    
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
