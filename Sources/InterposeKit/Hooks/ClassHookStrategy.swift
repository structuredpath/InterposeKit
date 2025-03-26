import Foundation

final class ClassHookStrategy: HookStrategy {
    
    init(
        `class`: AnyClass,
        selector: Selector,
        replacementIMP: IMP
    ) {
        self.class = `class`
        self.selector = selector
        self.replacementIMP = replacementIMP
    }
    
    let `class`: AnyClass
    let selector: Selector
    let replacementIMP: IMP
    var originalIMP: IMP?
    
    func replaceImplementation() throws {
        guard let method = class_getInstanceMethod(self.class, self.selector) else {
            throw InterposeError.methodNotFound(self.class, self.selector)
        }
        
        guard let originalIMP = class_replaceMethod(
            self.class,
            self.selector,
            self.replacementIMP,
            method_getTypeEncoding(method)
        ) else {
            throw InterposeError.nonExistingImplementation(self.class, self.selector)
        }
        
        self.originalIMP = originalIMP
        
        Interpose.log("Swizzled -[\(self.class).\(self.selector)] IMP: \(originalIMP) -> \(self.replacementIMP)")
    }
    
    func resetImplementation() throws {
        guard let method = class_getInstanceMethod(self.class, self.selector) else {
            throw InterposeError.methodNotFound(self.class, self.selector)
        }
        
        guard let originalIMP = self.originalIMP else {
            // Ignore? Throw error?
            fatalError("The original implementation should be loaded when resetting")
        }
        
        let previousIMP = class_replaceMethod(
            self.class,
            self.selector,
            originalIMP,
            method_getTypeEncoding(method)
        )
        
        guard previousIMP == self.replacementIMP else {
            throw InterposeError.unexpectedImplementation(self.class, self.selector, previousIMP)
        }
        
        Interpose.log("Restored -[\(self.class).\(self.selector)] IMP: \(originalIMP)")
    }
    
}

extension ClassHookStrategy: CustomDebugStringConvertible {
    var debugDescription: String {
        "\(self.selector) → \(String(describing: self.originalIMP))"
    }
}
