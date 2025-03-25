import Foundation

/// Base class, represents a hook to exactly one method.
public class AnyHook {
    /// The class this hook is based on.
    public let `class`: AnyClass

    /// The selector this hook interposes.
    public let selector: Selector

    /// The current state of the hook.
    public internal(set) var state = State.pending

    // else we validate init order
    var replacementIMP: IMP!

    // fetched at apply time, changes late, thus class requirement
    var origIMP: IMP?

    public typealias State = HookState
    
    init(`class`: AnyClass, selector: Selector) throws {
        self.selector = selector
        self.class = `class`

        // Check if method exists
        try validate()
    }

    func replaceImplementation() throws {
        preconditionFailure("Not implemented")
    }

    func resetImplementation() throws {
        preconditionFailure("Not implemented")
    }

    /// Apply the interpose hook.
    @discardableResult public func apply() throws -> AnyHook {
        try execute(newState: .active) { try replaceImplementation() }
        return self
    }

    /// Revert the interpose hook.
    @discardableResult public func revert() throws -> AnyHook {
        try execute(newState: .pending) { try resetImplementation() }
        return self
    }

    /// Validate that the selector exists on the active class.
    @discardableResult func validate(expectedState: State = .pending) throws -> Method {
        guard let method = class_getInstanceMethod(`class`, selector) else {
            throw InterposeError.methodNotFound(`class`, selector)
        }
        guard state == expectedState else {
            throw InterposeError.invalidState(expectedState: expectedState)
        }
        return method
    }

    private func execute(newState: State, task: () throws -> Void) throws {
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
            Interpose.log("Releasing -[\(`class`).\(selector)] IMP: \(replacementIMP!)")
            imp_removeBlock(replacementIMP)
        case .active:
            Interpose.log("Keeping -[\(`class`).\(selector)] IMP: \(replacementIMP!)")
        case .failed:
            Interpose.log("Leaking -[\(`class`).\(selector)] IMP: \(replacementIMP!)")
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
