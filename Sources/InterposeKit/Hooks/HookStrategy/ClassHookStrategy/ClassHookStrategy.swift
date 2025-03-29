import Foundation

final class ClassHookStrategy: HookStrategy {
    
    init(
        `class`: AnyClass,
        selector: Selector,
        makeHookIMP: @escaping () -> IMP
    ) {
        self.class = `class`
        self.selector = selector
        self.makeHookIMP = makeHookIMP
    }
    
    let `class`: AnyClass
    var scope: HookScope { .class }
    let selector: Selector
    private let makeHookIMP: () -> IMP
    private(set) var appliedHookIMP: IMP?
    private(set) var storedOriginalIMP: IMP?
    
    func validate() throws {
        guard class_getInstanceMethod(self.class, self.selector) != nil else {
            throw InterposeError.methodNotFound(self.class, self.selector)
        }
    }
    
    func replaceImplementation() throws {
        let hookIMP = self.makeHookIMP()
        self.appliedHookIMP = hookIMP
        
        guard let method = class_getInstanceMethod(self.class, self.selector) else {
            throw InterposeError.methodNotFound(self.class, self.selector)
        }
        
        guard let originalIMP = class_replaceMethod(
            self.class,
            self.selector,
            hookIMP,
            method_getTypeEncoding(method)
        ) else {
            throw InterposeError.nonExistingImplementation(self.class, self.selector)
        }
        
        self.storedOriginalIMP = originalIMP
        
        Interpose.log("Swizzled -[\(self.class).\(self.selector)] IMP: \(originalIMP) -> \(hookIMP)")
    }
    
    func restoreImplementation() throws {
        guard let hookIMP = self.appliedHookIMP else { return }
        
        defer {
            imp_removeBlock(hookIMP)
            self.appliedHookIMP = nil
        }
        
        guard let method = class_getInstanceMethod(self.class, self.selector) else {
            throw InterposeError.methodNotFound(self.class, self.selector)
        }
        
        guard let originalIMP = self.storedOriginalIMP else {
            // Ignore? Throw error?
            fatalError("The original implementation should be loaded when resetting")
        }
        
        let previousIMP = class_replaceMethod(
            self.class,
            self.selector,
            originalIMP,
            method_getTypeEncoding(method)
        )
        
        guard previousIMP == hookIMP else {
            throw InterposeError.unexpectedImplementation(self.class, self.selector, previousIMP)
        }
        
        Interpose.log("Restored -[\(self.class).\(self.selector)] IMP: \(originalIMP)")
    }
    
}

extension ClassHookStrategy: CustomDebugStringConvertible {
    internal var debugDescription: String {
        "\(self.selector) → \(String(describing: self.storedOriginalIMP))"
    }
}
