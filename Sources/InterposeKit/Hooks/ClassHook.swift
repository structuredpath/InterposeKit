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
            origIMP = class_replaceMethod(`class`, selector, self.strategy.replacementIMP, method_getTypeEncoding(method))
            guard origIMP != nil else { throw InterposeError.nonExistingImplementation(`class`, selector) }
            Interpose.log("Swizzled -[\(`class`).\(selector)] IMP: \(origIMP!) -> \(self.strategy.replacementIMP)")
        }

        override func resetImplementation() throws {
            let method = try validate(expectedState: .active)
            precondition(origIMP != nil)
            let previousIMP = class_replaceMethod(`class`, selector, origIMP!, method_getTypeEncoding(method))
            guard previousIMP == self.strategy.replacementIMP else {
                throw InterposeError.unexpectedImplementation(`class`, selector, previousIMP)
            }
            Interpose.log("Restored -[\(`class`).\(selector)] IMP: \(origIMP!)")
        }

        /// The original implementation is cached at hook time.
        public override var original: MethodSignature {
           unsafeBitCast(origIMP, to: MethodSignature.self)
        }
    }
}

#if DEBUG
extension Interpose.ClassHook: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "\(selector) -> \(String(describing: origIMP))"
    }
}
#endif
