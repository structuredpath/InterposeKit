import Foundation

extension Interpose {

    /// A hook to an instance method of a single object, stores both the original and new implementation.
    /// Think about: Multiple hooks for one object
    final public class ObjectHook: Hook {

        /// Initialize a new hook to interpose an instance method.
        public init<MethodSignature, HookSignature>(
            object: AnyObject,
            selector: Selector,
            build: HookBuilder<MethodSignature, HookSignature>
        ) throws {
            let strategyProvider: (Hook) -> any HookStrategy = { hook in
                let hookProxy = HookProxy(
                    selector: selector,
                    originalProvider: {
                        unsafeBitCast(
                            hook.originalIMP,
                            to: MethodSignature.self
                        )
                    }
                )
                
                let block = build(hookProxy) as AnyObject
                let replacementIMP = imp_implementationWithBlock(block)
                
                // Weakly store reference to hook inside the block of the IMP.
                Interpose.storeHook(hook: hook, to: replacementIMP)
                
                return ObjectHookStrategy(
                    object: object,
                    selector: selector,
                    replacementIMP: replacementIMP
                )
            }
            
            try super.init(
                class: type(of: object),
                selector: selector,
                strategyProvider: strategyProvider
            )
        }

        override func replaceImplementation() throws {
            try (self.strategy as! ObjectHookStrategy).replaceImplementation()
        }

        override func resetImplementation() throws {
            try (self.strategy as! ObjectHookStrategy).resetImplementation(hook: self)
        }
    }
}

//#if DEBUG
//extension Interpose.ObjectHook: CustomDebugStringConvertible {
//    public var debugDescription: String {
//        return "\(selector) of \(object) -> \(String(describing: original))"
//    }
//}
//#endif

final class ObjectHookStrategy: HookStrategy {
    
    init(
        object: AnyObject,
        selector: Selector,
        replacementIMP: IMP
    ) {
        self.object = object
        self.class = type(of: object)
        self.selector = selector
        self.replacementIMP = replacementIMP
    }
    
    let object: AnyObject
    let `class`: AnyClass
    let selector: Selector
    let replacementIMP: IMP
    var storedOriginalIMP: IMP?
    
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
        let replacementIMP = self.replacementIMP
        
        if self.generatesSuperIMP {
            // If the subclass is empty, we create a super trampoline first.
            // If a hook already exists, we must skip this.
            if !hasExistingMethod {
                self.interposeSubclass!.addSuperTrampoline(selector: self.selector)
            }
            
            // Replace IMP (by now we guarantee that it exists)
            self.storedOriginalIMP = class_replaceMethod(self.dynamicSubclass, self.selector, replacementIMP, encoding)
            guard self.storedOriginalIMP != nil else {
                throw InterposeError.nonExistingImplementation(self.dynamicSubclass, self.selector)
            }
            Interpose.log("Added -[\(self.class).\(self.selector)] IMP: \(self.storedOriginalIMP!) -> \(replacementIMP)")
        } else {
            // Could potentially be unified in the code paths
            if hasExistingMethod {
                self.storedOriginalIMP = class_replaceMethod(self.dynamicSubclass, self.selector, replacementIMP, encoding)
                if self.storedOriginalIMP != nil {
                    Interpose.log("Added -[\(self.class).\(self.selector)] IMP: \(replacementIMP) via replacement")
                } else {
                    Interpose.log("Unable to replace: -[\(self.class).\(self.selector)] IMP: \(replacementIMP)")
                    throw InterposeError.unableToAddMethod(self.class, self.selector)
                }
            } else {
                let didAddMethod = class_addMethod(self.dynamicSubclass, self.selector, replacementIMP, encoding)
                if didAddMethod {
                    Interpose.log("Added -[\(self.class).\(self.selector)] IMP: \(replacementIMP)")
                } else {
                    Interpose.log("Unable to add: -[\(self.class).\(self.selector)] IMP: \(replacementIMP)")
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
    
    func resetImplementation(hook: Hook) throws {
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
        let replacementIMP = self.replacementIMP
        if currentIMP == replacementIMP {
            let previousIMP = class_replaceMethod(self.dynamicSubclass, self.selector, self.storedOriginalIMP!, method_getTypeEncoding(method))
            guard previousIMP == replacementIMP else {
                throw InterposeError.unexpectedImplementation(self.dynamicSubclass, selector, previousIMP)
            }
            Interpose.log("Restored -[\(self.class).\(self.selector)] IMP: \(self.storedOriginalIMP!)")
        } else {
            let nextHook = Interpose.findNextHook(selfHook: hook, topmostIMP: currentIMP)
            // Replace next's original IMP
            (nextHook?.strategy as? ObjectHookStrategy)?.storedOriginalIMP = self.storedOriginalIMP
        }
        
        // FUTURE: remove class pair!
        // This might fail if we get KVO observed.
        // objc_disposeClassPair does not return a bool but logs if it fails.
        //
        // objc_disposeClassPair(dynamicSubclass)
        // self.dynamicSubclass = nil
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
