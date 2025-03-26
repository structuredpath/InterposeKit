import Foundation

// TODO: Make originalIMP private

/// A runtime hook that interposes a single instance method on a class or object.
public final class Hook {
    
    // ============================================================================ //
    // MARK: Initialization
    // ============================================================================ //
    
    internal convenience init<MethodSignature, HookSignature>(
        `class`: AnyClass,
        selector: Selector,
        build: HookBuilder<MethodSignature, HookSignature>
    ) throws {
        try self.init(
            target: .class(`class`),
            selector: selector,
            build: build
        )
    }
    
    internal convenience init<MethodSignature, HookSignature>(
        object: AnyObject,
        selector: Selector,
        build: HookBuilder<MethodSignature, HookSignature>
    ) throws {
        try self.init(
            target: .object(object),
            selector: selector,
            build: build
        )
    }
    
    private init<MethodSignature, HookSignature>(
        target: HookTarget,
        selector: Selector,
        build: HookBuilder<MethodSignature, HookSignature>
    ) throws {
        func makeStrategy(_ hook: Hook) throws -> HookStrategy {
            let hookProxy = HookProxy(
                selector: selector,
                originalProvider: {
                    unsafeBitCast(
                        self.originalIMP,
                        to: MethodSignature.self
                    )
                }
            )
            
            let hookBlock = build(hookProxy)
            let hookIMP = imp_implementationWithBlock(hookBlock)
            
            switch target {
            case .class(let `class`):
                return try ClassHookStrategy(
                    class: `class`,
                    selector: selector,
                    hookIMP: hookIMP
                )
            case .object(let object):
                return try ObjectHookStrategy(
                    object: object,
                    selector: selector,
                    hookIMP: hookIMP
                )
            }
        }
        
        self._strategy = try makeStrategy(self)
    }
    
    // ============================================================================ //
    // MARK: ...
    // ============================================================================ //
    
    /// The class whose instance method is being interposed.
    public var `class`: AnyClass {
        self.strategy.class
    }
    
    public var scope: HookScope {
        self.strategy.scope
    }

    /// The selector identifying the instance method being interposed.
    public var selector: Selector {
        self.strategy.selector
    }

    /// The current state of the hook.
    public internal(set) var state = HookState.pending
    
    private var _strategy: HookStrategy!
    
    private var strategy: HookStrategy {
        self._strategy
    }

    /// The effective original implementation of the hook. Might be looked up at runtime.
    /// Do not cache this.
    internal var originalIMP: IMP? {
        self.strategy.originalIMP
    }

    /// Applies the hook by interposing the method implementation.
    public func apply() throws {
        try execute(newState: .active) {
            try self.strategy.replaceImplementation()
        }
    }

    /// Reverts the hook, restoring the original method implementation.
    public func revert() throws {
        try execute(newState: .pending) {
            try self.strategy.restoreImplementation()
        }
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
            Interpose.log("Releasing -[\(`class`).\(selector)] IMP: \(self.strategy.hookIMP)")
            imp_removeBlock(strategy.hookIMP)
        case .active:
            Interpose.log("Keeping -[\(`class`).\(selector)] IMP: \(self.strategy.hookIMP)")
        case .failed:
            Interpose.log("Leaking -[\(`class`).\(selector)] IMP: \(self.strategy.hookIMP)")
        }
    }
    
}

extension Hook: CustomDebugStringConvertible {
    public var debugDescription: String {
        self.strategy.debugDescription
    }
}

fileprivate enum HookTarget {
    case `class`(AnyClass)
    case object(AnyObject)
}
