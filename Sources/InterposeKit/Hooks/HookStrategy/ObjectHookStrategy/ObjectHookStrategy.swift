import Foundation

final class ObjectHookStrategy: HookStrategy {
    
    init(
        object: AnyObject,
        selector: Selector,
        hookIMP: IMP
    ) {
        self.object = object
        self.class = type(of: object)
        self.selector = selector
        self.hookIMP = hookIMP
        
        ObjectHookRegistry.register(self.handle, for: hookIMP)
    }
    
    let object: AnyObject
    let `class`: AnyClass
    let selector: Selector
    let hookIMP: IMP
    
    var storedOriginalIMP: IMP?
    
    private lazy var handle = ObjectHookHandle(
        getOriginalIMP: { self.storedOriginalIMP },
        setOriginalIMP: { self.storedOriginalIMP = $0 }
    )
    
    /// The original implementation of the hook. Might be looked up at runtime. Do not cache this.
    /// Actually not optional…
    var originalIMP: IMP? {
        // If we switched implementations, return stored.
        if let storedOrigIMP = self.storedOriginalIMP {
            return storedOrigIMP
        }
        // Else, perform a dynamic lookup
        guard let origIMP = self.lookupOrigIMP else {
            InterposeError.nonExistingImplementation(`class`, selector).log()
            preconditionFailure("IMP must be found for call")
        }
        return origIMP
    }
    
    /// Subclass that we create on the fly
    var interposeSubclass: InterposeSubclass?
    
    // Logic switch to use super builder
    let generatesSuperIMP = InterposeSubclass.supportsSuperTrampolines
    
    var dynamicSubclass: AnyClass {
        interposeSubclass!.dynamicClass
    }
    
    /// We look for the parent IMP dynamically, so later modifications to the class are no problem.
    var lookupOrigIMP: IMP? {
        var currentClass: AnyClass? = self.class
        repeat {
            if let currentClass = currentClass,
               let method = class_getInstanceMethod(currentClass, self.selector) {
                let origIMP = method_getImplementation(method)
                return origIMP
            }
            currentClass = class_getSuperclass(currentClass)
        } while currentClass != nil
        return nil
    }
    
    func replaceImplementation() throws {
        guard let method = class_getInstanceMethod(self.class, self.selector) else {
            throw InterposeError.methodNotFound(self.class, self.selector)
        }
        
        // Check if there's an existing subclass we can reuse.
        // Create one at runtime if there is none.
        self.interposeSubclass = try InterposeSubclass(object: self.object)
        
        // The implementation of the call that is hooked must exist.
        guard self.lookupOrigIMP != nil else {
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
            let nextHook = self.findNextHook(selfHook: self.handle, topmostIMP: currentIMP)
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
    
    // Find the hook above us (not necessarily topmost)
    private func findNextHook(selfHook: ObjectHookHandle, topmostIMP: IMP) -> ObjectHookHandle? {
        // We are not topmost hook, so find the hook above us!
        var impl: IMP? = topmostIMP
        var currentHook: ObjectHookHandle?
        repeat {
            // get topmost hook
            let hook: ObjectHookHandle? = ObjectHookRegistry.handle(for: impl!)
            if hook === selfHook {
                // return parent
                return currentHook
            }
            // crawl down the chain until we find ourselves
            currentHook = hook
            impl = hook?.originalIMP
        } while impl != nil
        return nil
    }
    
    //    /// Release the hook block if possible.
    //    public override func cleanup() {
    //        // remove subclass!
    //        super.cleanup()
    //    }
    
}

extension ObjectHookStrategy: CustomDebugStringConvertible {
    var debugDescription: String {
        ""
    }
}

//#if DEBUG
//extension Interpose.ObjectHook: CustomDebugStringConvertible {
//    public var debugDescription: String {
//        return "\(selector) of \(object) -> \(String(describing: original))"
//    }
//}
//#endif
