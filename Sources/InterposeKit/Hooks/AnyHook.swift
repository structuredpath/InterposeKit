import Foundation

/// Base class, represents a hook to exactly one method.
public class AnyHook: Hook {
    /// The class this hook is based on.
    public let `class`: AnyClass

    /// The selector this hook interposes.
    public let selector: Selector

    /// The current state of the hook.
    public internal(set) var state = HookState.pending

    private var _strategy: AnyHookStrategy!
    var strategy: AnyHookStrategy { _strategy }

    init(`class`: AnyClass, selector: Selector, strategyProvider: (AnyHook) -> AnyHookStrategy) throws {
        self.selector = selector
        self.class = `class`

        // Check if method exists
        try validate()
        
        self._strategy = strategyProvider(self)
    }

    func replaceImplementation() throws {
        preconditionFailure("Not implemented")
    }

    func resetImplementation() throws {
        preconditionFailure("Not implemented")
    }

    /// Apply the interpose hook.
    public func apply() throws {
        try execute(newState: .active) { try replaceImplementation() }
    }

    /// Revert the interpose hook.
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

    /// Release the hook block if possible.
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

/// Hook baseclass with generic signatures.
public class TypedHook<MethodSignature, HookSignature>: AnyHook {
    /// The original implementation of the hook. Might be looked up at runtime. Do not cache this.
    public var original: MethodSignature {
        preconditionFailure("Always override")
    }
}
