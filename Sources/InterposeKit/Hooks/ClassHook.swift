import Foundation

extension Interpose {
    /// A hook to an instance method and stores both the original and new implementation.
    final public class ClassHook<MethodSignature, HookSignature>: TypedHook<MethodSignature, HookSignature> {
        
        public init(
            `class`: AnyClass,
            selector: Selector,
            implementation: HookImplementationBuilder<MethodSignature, HookSignature>
        ) throws {
            let strategyProvider: (AnyHook) -> _HookStrategy = { hook in
                let hook = hook as! Self
                let replacementIMP = imp_implementationWithBlock(implementation(hook))
                
                return ClassHookStrategy<MethodSignature>(
                    class: `class`,
                    selector: selector,
                    replacementIMP: replacementIMP
                )
            }
            
            try super.init(
                class: `class`,
                selector: selector,
                strategyProvider: strategyProvider
            )
        }
        
    }
}

final class ClassHookStrategy<MethodSignature>: HookStrategy {
    
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
    
    var original: MethodSignature {
        unsafeBitCast(self.originalIMP, to: MethodSignature.self)
    }
    
}

#if DEBUG
extension Interpose.ClassHook: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "\(selector) -> \(String(describing: self.strategy.originalIMP))"
    }
}
#endif
