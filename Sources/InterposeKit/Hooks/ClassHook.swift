import Foundation

extension Interpose {
    /// A hook to an instance method and stores both the original and new implementation.
    final public class ClassHook<MethodSignature, HookSignature>: TypedHook<MethodSignature, HookSignature> {
        
        public init(
            `class`: AnyClass,
            selector: Selector,
            implementation: (ClassHook<MethodSignature, HookSignature>) -> HookSignature
        ) throws {
            let strategyProvider: (AnyHook) -> AnyHookStrategy = { hook in
                let hook = hook as! Self
                let replacementIMP = imp_implementationWithBlock(implementation(hook))
                return AnyHookStrategy(replacementIMP: replacementIMP)
            }
            
            try super.init(
                class: `class`,
                selector: selector,
                strategyProvider: strategyProvider
            )
        }

        override func replaceImplementation() throws {
            let method = try validate()
            self.strategy.originalIMP = class_replaceMethod(`class`, selector, self.strategy.replacementIMP, method_getTypeEncoding(method))
            guard self.strategy.originalIMP != nil else { throw InterposeError.nonExistingImplementation(`class`, selector) }
            Interpose.log("Swizzled -[\(`class`).\(selector)] IMP: \(self.strategy.originalIMP!) -> \(self.strategy.replacementIMP)")
        }

        override func resetImplementation() throws {
            let method = try validate(expectedState: .active)
            precondition(self.strategy.originalIMP != nil)
            let previousIMP = class_replaceMethod(`class`, selector, self.strategy.originalIMP!, method_getTypeEncoding(method))
            guard previousIMP == self.strategy.replacementIMP else {
                throw InterposeError.unexpectedImplementation(`class`, selector, previousIMP)
            }
            Interpose.log("Restored -[\(`class`).\(selector)] IMP: \(self.strategy.originalIMP!)")
        }

        /// The original implementation is cached at hook time.
        public override var original: MethodSignature {
            unsafeBitCast(self.strategy.originalIMP, to: MethodSignature.self)
        }
    }
}

#if DEBUG
extension Interpose.ClassHook: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "\(selector) -> \(String(describing: self.strategy.originalIMP))"
    }
}
#endif
