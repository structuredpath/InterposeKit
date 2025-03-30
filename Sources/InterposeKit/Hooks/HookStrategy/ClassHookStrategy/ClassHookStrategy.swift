import Foundation

internal final class ClassHookStrategy: HookStrategy {
    
    // ============================================================================ //
    // MARK: Initialization
    // ============================================================================ //
    
    internal init(
        `class`: AnyClass,
        selector: Selector,
        makeHookIMP: @escaping () -> IMP
    ) {
        self.class = `class`
        self.selector = selector
        self.makeHookIMP = makeHookIMP
    }
    
    // ============================================================================ //
    // MARK: Configuration
    // ============================================================================ //
    
    internal let `class`: AnyClass
    internal var scope: HookScope { .class }
    internal let selector: Selector
    private let makeHookIMP: () -> IMP
    
    // ============================================================================ //
    // MARK: Implementations
    // ============================================================================ //
    
    private(set) internal var appliedHookIMP: IMP?
    private(set) internal var storedOriginalIMP: IMP?
    
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
        
        guard class_implementsInstanceMethod(self.class, self.selector) else {
            throw InterposeError.methodNotDirectlyImplemented(
                class: self.class,
                selector: self.selector
            )
        }
    }
    
    // ============================================================================ //
    // MARK: Installing Implementation
    // ============================================================================ //
    
    internal func replaceImplementation() throws {
        let hookIMP = self.makeHookIMP()
        
        guard let method = class_getInstanceMethod(self.class, self.selector) else {
            throw InterposeError.methodNotFound(
                class: self.class,
                selector: self.selector
            )
        }
        
        guard let originalIMP = class_replaceMethod(
            self.class,
            self.selector,
            hookIMP,
            method_getTypeEncoding(method)
        ) else {
            throw InterposeError.implementationNotFound(
                class: self.class,
                selector: self.selector
            )
        }

        self.appliedHookIMP = hookIMP
        self.storedOriginalIMP = originalIMP
        
        Interpose.log("Swizzled -[\(self.class) \(self.selector)] IMP: \(originalIMP) -> \(hookIMP)")
    }
    
    internal func restoreImplementation() throws {
        guard let hookIMP = self.appliedHookIMP else { return }
        guard let originalIMP = self.storedOriginalIMP else { return }
        
        defer {
            imp_removeBlock(hookIMP)
            self.appliedHookIMP = nil
            self.storedOriginalIMP = nil
        }
        
        guard let method = class_getInstanceMethod(self.class, self.selector) else {
            throw InterposeError.methodNotFound(
                class: self.class,
                selector: self.selector
            )
        }
        
        let previousIMP = class_replaceMethod(
            self.class,
            self.selector,
            originalIMP,
            method_getTypeEncoding(method)
        )
        
        guard previousIMP == hookIMP else {
            throw InterposeError.revertCorrupted(
                class: self.class,
                selector: self.selector,
                imp: previousIMP
            )
        }
        
        Interpose.log("Restored -[\(self.class) \(self.selector)] IMP: \(originalIMP)")
    }
    
}
