import Foundation

// TODO: Make final
// TODO: Make strategy private
// TODO: Make main init private

/// A runtime hook that interposes a single instance method on a class or object.
public class Hook {
    
    // ============================================================================ //
    // MARK: Initialization
    // ============================================================================ //
    
    internal convenience init<MethodSignature, HookSignature>(
        `class`: AnyClass,
        selector: Selector,
        implementation: HookImplementationBuilder<MethodSignature, HookSignature>
    ) throws {
        let strategyProvider: (Hook) -> HookStrategy = { hook in
            let hookProxy = HookProxy(
                selector: selector,
                originalProvider: {
                    unsafeBitCast(
                        hook.strategy.originalIMP,
                        to: MethodSignature.self
                    )
                }
            )
            
            let replacementIMP = imp_implementationWithBlock(implementation(hookProxy))
            
            return ClassHookStrategy(
                class: `class`,
                selector: selector,
                replacementIMP: replacementIMP
            )
        }
        
        try self.init(
            class: `class`,
            selector: selector,
            strategyProvider: strategyProvider
        )
    }
    
    init(
        `class`: AnyClass,
        selector: Selector,
        strategyProvider: (Hook) -> HookStrategy
    ) throws {
        self.selector = selector
        self.class = `class`
        
        // Check if method exists
        try validate()
        
        self._strategy = strategyProvider(self)
    }
    
    // ============================================================================ //
    // MARK: ...
    // ============================================================================ //
    
    /// The class whose instance method is being interposed.
    public let `class`: AnyClass

    /// The selector identifying the instance method being interposed.
    public let selector: Selector

    /// The current state of the hook.
    public internal(set) var state = HookState.pending
    
    private var _strategy: HookStrategy!
    var strategy: HookStrategy { _strategy }

    

    func replaceImplementation() throws {
        if let strategy = self.strategy as? ClassHookStrategy {
            return try strategy.replaceImplementation()
        } else {
            preconditionFailure("Not implemented")
        }
    }
    
    func resetImplementation() throws {
        if let strategy = self.strategy as? ClassHookStrategy {
            return try strategy.resetImplementation()
        } else {
            preconditionFailure("Not implemented")
        }
    }
    
    /// The original implementation of the hook. Might be looked up at runtime. Do not cache this.
    var originalIMP: IMP? {
        if let strategy = self.strategy as? ClassHookStrategy {
            return strategy.originalIMP
        } else {
            preconditionFailure("Not implemented")
        }
    }

    /// Applies the hook by interposing the method implementation.
    public func apply() throws {
        try execute(newState: .active) { try replaceImplementation() }
    }

    /// Reverts the hook, restoring the original method implementation.
    public func revert() throws {
        try execute(newState: .pending) { try resetImplementation() }
    }
    
    /// Validate that the selector exists on the active class.
    @discardableResult func validate(expectedState: HookState = .pending) throws -> Method {
        guard let method = class_getInstanceMethod(`class`, selector) else {
            throw InterposeError.methodNotFound(`class`, selector)
        }
        guard state == expectedState else {
            throw InterposeError.invalidState(expectedState: expectedState)
        }
        return method
    }

    private func execute(newState: HookState, task: () throws -> Void) throws {
        do {
            try task()
            state = newState
        } catch let error as InterposeError {
            state = .failed
            throw error
        }
    }

    // TODO: Rename to `cleanUp()`
    public func cleanup() {
        switch state {
        case .pending:
            Interpose.log("Releasing -[\(`class`).\(selector)] IMP: \(self.strategy.replacementIMP)")
            imp_removeBlock(strategy.replacementIMP)
        case .active:
            Interpose.log("Keeping -[\(`class`).\(selector)] IMP: \(self.strategy.replacementIMP)")
        case .failed:
            Interpose.log("Leaking -[\(`class`).\(selector)] IMP: \(self.strategy.replacementIMP)")
        }
    }
    
}
