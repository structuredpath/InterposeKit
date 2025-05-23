import ObjectiveC

internal final class ClassHookStrategy: HookStrategy {
    
    // ============================================================================ //
    // MARK: Initialization
    // ============================================================================ //
    
    internal init(
        `class`: AnyClass,
        methodKind: MethodKind,
        selector: Selector,
        makeHookIMP: @escaping () -> IMP
    ) {
        self.class = `class`
        self.selector = selector
        self.methodKind = methodKind
        self.makeHookIMP = makeHookIMP
    }
    
    // ============================================================================ //
    // MARK: Configuration
    // ============================================================================ //
    
    internal let `class`: AnyClass
    internal var scope: HookScope { .class(self.methodKind) }
    internal let selector: Selector
    
    private let methodKind: MethodKind
    private let makeHookIMP: () -> IMP
    
    // ============================================================================ //
    // MARK: Implementations
    // ============================================================================ //
    
    private(set) internal var appliedHookIMP: IMP?
    private(set) internal var storedOriginalIMP: IMP?
    
    // ============================================================================ //
    // MARK: Target Class
    // ============================================================================ //
    
    /// The target class resolved for the configured method kind.
    ///
    /// This is the class itself for instance methods, or the metaclass for class methods.
    private lazy var targetClass: AnyClass = {
        switch self.methodKind {
        case .instance:
            return self.class
        case .class:
            return object_getClass(self.class)
        }
    }()
    
    // ============================================================================ //
    // MARK: Validation
    // ============================================================================ //
    
    internal func validate() throws {
        // Ensure that the method exists.
        guard class_getInstanceMethod(self.targetClass, self.selector) != nil else {
            throw InterposeError.methodNotFound(
                class: self.class,
                kind: self.methodKind,
                selector: self.selector
            )
        }
        
        // Ensure that the class directly implements the method.
        guard class_implementsInstanceMethod(self.targetClass, self.selector) else {
            throw InterposeError.methodNotDirectlyImplemented(
                class: self.class,
                kind: self.methodKind,
                selector: self.selector
            )
        }
    }
    
    // ============================================================================ //
    // MARK: Installing Implementation
    // ============================================================================ //
    
    internal func replaceImplementation() throws {
        let hookIMP = self.makeHookIMP()
        
        guard let method = class_getInstanceMethod(self.targetClass, self.selector) else {
            // This should not happen under normal circumstances, as we perform validation upon
            // creating the hook strategy, which itself checks for the presence of the method.
            throw InterposeError.methodNotFound(
                class: self.class,
                kind: self.methodKind,
                selector: self.selector
            )
        }
        
        guard let originalIMP = class_replaceMethod(
            self.targetClass,
            self.selector,
            hookIMP,
            method_getTypeEncoding(method)
        ) else {
            // This should not happen under normal circumstances, as we perform validation upon
            // creating the hook strategy, which checks if the class directly implements the method.
            throw InterposeError.implementationNotFound(
                class: self.targetClass,
                kind: self.methodKind,
                selector: self.selector
            )
        }

        self.appliedHookIMP = hookIMP
        self.storedOriginalIMP = originalIMP
        
        Interpose.log({
            let selector = "\(self.methodKind.symbolPrefix)[\(self.class) \(self.selector)]"
            return "Replaced implementation for \(selector) IMP: \(originalIMP) -> \(hookIMP)"
        }())
    }
    
    internal func restoreImplementation() throws {
        guard let hookIMP = self.appliedHookIMP else { return }
        guard let originalIMP = self.storedOriginalIMP else { return }
        
        defer {
            imp_removeBlock(hookIMP)
            self.appliedHookIMP = nil
            self.storedOriginalIMP = nil
        }
        
        guard let method = class_getInstanceMethod(self.targetClass, self.selector) else {
            throw InterposeError.methodNotFound(
                class: self.class,
                kind: self.methodKind,
                selector: self.selector
            )
        }
        
        let previousIMP = class_replaceMethod(
            self.targetClass,
            self.selector,
            originalIMP,
            method_getTypeEncoding(method)
        )
        
        guard previousIMP == hookIMP else {
            throw InterposeError.revertCorrupted(
                class: self.class,
                kind: self.methodKind,
                selector: self.selector,
                imp: previousIMP
            )
        }
        
        Interpose.log({
            let selector = "\(self.methodKind.symbolPrefix)[\(self.class) \(self.selector)]"
            return "Restored implementation for \(selector) IMP: \(originalIMP)"
        }())
    }
    
}
