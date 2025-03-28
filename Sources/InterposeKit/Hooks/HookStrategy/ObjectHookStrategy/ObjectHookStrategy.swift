import Foundation

final class ObjectHookStrategy: HookStrategy {
    
    init(
        object: NSObject,
        selector: Selector,
        hookIMP: IMP
    ) throws {
        self.class = type(of: object)
        self.object = object
        self.selector = selector
        self.hookIMP = hookIMP

        try self.validate()
        
        if let _ = checkObjectPosingAsDifferentClass(object) {
            if object_isKVOActive(object) {
                throw InterposeError.keyValueObservationDetected(object)
            }
            // TODO: Handle the case where the object is posing as different class but not the interpose subclass
        }
        
        ObjectHookRegistry.register(self.handle, for: hookIMP)
    }
    
    let `class`: AnyClass
    let object: AnyObject
    var scope: HookScope { .object(self.object) }
    let selector: Selector
    
    let hookIMP: IMP
    private(set) var storedOriginalIMP: IMP?
    
    private lazy var handle = ObjectHookHandle(
        getOriginalIMP: { self.storedOriginalIMP },
        setOriginalIMP: { self.storedOriginalIMP = $0 }
    )
    
    /// Subclass that we create on the fly
    var interposeSubclass: InterposeSubclass?
    
    // Logic switch to use super builder
    let generatesSuperIMP = InterposeSubclass.supportsSuperTrampolines
    
    var dynamicSubclass: AnyClass {
        interposeSubclass!.dynamicClass
    }
    
    func replaceImplementation() throws {
        guard let method = class_getInstanceMethod(self.class, self.selector) else {
            throw InterposeError.methodNotFound(self.class, self.selector)
        }
        
        // Check if there's an existing subclass we can reuse.
        // Create one at runtime if there is none.
        self.interposeSubclass = try InterposeSubclass(object: self.object)
        
        // The implementation of the call that is hooked must exist.
        guard self.lookUpIMP() != nil else {
            throw InterposeError.nonExistingImplementation(self.class, self.selector).log()
        }
        
        //  This function searches superclasses for implementations
        let hasExistingMethod = self.exactClassImplementsSelector(self.dynamicSubclass, self.selector)
        let encoding = method_getTypeEncoding(method)
        
        if self.generatesSuperIMP {
            // If the subclass is empty, we create a super trampoline first.
            // If a hook already exists, we must skip this.
            if !hasExistingMethod {
                self.interposeSubclass!.addSuperTrampoline(selector: self.selector)
            }
            
            // Replace IMP (by now we guarantee that it exists)
            self.storedOriginalIMP = class_replaceMethod(self.dynamicSubclass, self.selector, self.hookIMP, encoding)
            guard self.storedOriginalIMP != nil else {
                throw InterposeError.nonExistingImplementation(self.dynamicSubclass, self.selector)
            }
            Interpose.log("Added -[\(self.class).\(self.selector)] IMP: \(self.storedOriginalIMP!) -> \(self.hookIMP)")
        } else {
            // Could potentially be unified in the code paths
            if hasExistingMethod {
                self.storedOriginalIMP = class_replaceMethod(self.dynamicSubclass, self.selector, self.hookIMP, encoding)
                if self.storedOriginalIMP != nil {
                    Interpose.log("Added -[\(self.class).\(self.selector)] IMP: \(self.hookIMP) via replacement")
                } else {
                    Interpose.log("Unable to replace: -[\(self.class).\(self.selector)] IMP: \(self.hookIMP)")
                    throw InterposeError.unableToAddMethod(self.class, self.selector)
                }
            } else {
                let didAddMethod = class_addMethod(self.dynamicSubclass, self.selector, self.hookIMP, encoding)
                if didAddMethod {
                    Interpose.log("Added -[\(self.class).\(self.selector)] IMP: \(self.hookIMP)")
                } else {
                    Interpose.log("Unable to add: -[\(self.class).\(self.selector)] IMP: \(self.hookIMP)")
                    throw InterposeError.unableToAddMethod(self.class, self.selector)
                }
            }
        }
    }
    
    /// Looks for an instance method in the exact class, without looking up the hierarchy.
    private func exactClassImplementsSelector(_ klass: AnyClass, _ selector: Selector) -> Bool {
        var methodCount: CUnsignedInt = 0
        guard let methodsInAClass = class_copyMethodList(klass, &methodCount) else { return false }
        defer { free(methodsInAClass) }
        for index in 0 ..< Int(methodCount) {
            let method = methodsInAClass[index]
            if method_getName(method) == selector {
                return true
            }
        }
        return false
    }
    
    func restoreImplementation() throws {
        guard let method = class_getInstanceMethod(self.class, self.selector) else {
            throw InterposeError.methodNotFound(self.class, self.selector)
        }
        
        guard self.storedOriginalIMP != nil else {
            // Removing methods at runtime is not supported.
            // https://stackoverflow.com/questions/1315169/how-do-i-remove-instance-methods-at-runtime-in-objective-c-2-0
            //
            // This codepath will be hit if the super helper is missing.
            // We could recreate the whole class at runtime and rebuild all hooks,
            // but that seems excessive when we have a trampoline at our disposal.
            Interpose.log("Reset of -[\(self.class).\(self.selector)] not supported. No IMP")
            throw InterposeError.resetUnsupported("No Original IMP found. SuperBuilder missing?")
        }
        
        guard let currentIMP = class_getMethodImplementation(self.dynamicSubclass, self.selector) else {
            throw InterposeError.unknownError("No Implementation found")
        }
        
        // We are the topmost hook, replace method.
        if currentIMP == self.hookIMP {
            let previousIMP = class_replaceMethod(self.dynamicSubclass, self.selector, self.storedOriginalIMP!, method_getTypeEncoding(method))
            guard previousIMP == self.hookIMP else {
                throw InterposeError.unexpectedImplementation(self.dynamicSubclass, selector, previousIMP)
            }
            Interpose.log("Restored -[\(self.class).\(self.selector)] IMP: \(self.storedOriginalIMP!)")
        } else {
            let nextHook = self._findParentHook(from: currentIMP)
            // Replace next's original IMP
            nextHook?.originalIMP = self.storedOriginalIMP
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

extension ObjectHookStrategy: CustomDebugStringConvertible {
    internal var debugDescription: String {
        "\(self.selector) of \(self.object) → \(String(describing: self.originalIMP))"
    }
}
