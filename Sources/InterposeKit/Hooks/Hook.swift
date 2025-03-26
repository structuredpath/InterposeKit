import ObjectiveC

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
                getOriginal: {
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
        
        self.strategy = try makeStrategy(self)
    }
    
    // ============================================================================ //
    // MARK: Target Info
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
    
    // ============================================================================ //
    // MARK: State
    // ============================================================================ //

    /// The current state of the hook.
    public internal(set) var state = HookState.pending
    
    // ============================================================================ //
    // MARK: Applying & Reverting
    // ============================================================================ //

    /// Applies the hook by interposing the method implementation.
    public func apply() throws {
        guard self.state == .pending else { return }
        
        do {
            try self.strategy.replaceImplementation()
            self.state = .active
        } catch {
            self.state = .failed
            throw error
        }
    }

    /// Reverts the hook, restoring the original method implementation.
    public func revert() throws {
        guard self.state == .active else { return }
        
        do {
            try self.strategy.restoreImplementation()
            self.state = .pending
        } catch {
            self.state = .failed
            throw error
        }
    }

    // ============================================================================ //
    // MARK: Original Implementation
    // ============================================================================ //
    
    // TODO: Make originalIMP private
    
    /// The effective original implementation of the hook. Might be looked up at runtime.
    /// Do not cache this.
    internal var originalIMP: IMP? {
        self.strategy.originalIMP
    }
    
    // ============================================================================ //
    // MARK: Underlying Strategy
    // ============================================================================ //

    /// The active strategy used to interpose and manage the method implementation.
    ///
    /// This is an implicitly unwrapped optional, assigned immediately after initialization,
    /// as constructing the strategy requires `self` to build the hook proxy.
    private var strategy: HookStrategy!
    
}

extension Hook: CustomDebugStringConvertible {
    public var debugDescription: String {
        self.strategy.debugDescription
    }
}

// TODO: Try to make clean-up automatic in deinit
extension Hook {
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

public typealias HookBuilder<MethodSignature, HookSignature> = (HookProxy<MethodSignature>) -> HookSignature

public final class HookProxy<MethodSignature> {
    
    internal init(
        selector: Selector,
        getOriginal: @escaping () -> MethodSignature
    ) {
        self.selector = selector
        self._getOriginal = getOriginal
    }
    
    public let selector: Selector
    
    private let _getOriginal: () -> MethodSignature
    
    public var original: MethodSignature {
        self._getOriginal()
    }
    
}

public enum HookScope {
    
    /// The scope that targets all instances of the class.
    case `class`
    
    /// The scope that targets a specific instance of the class.
    case object(AnyObject)
    
}

public enum HookState: Equatable {
    
    /// The hook is ready to be applied.
    case pending
    
    /// The hook has been successfully applied.
    case active
    
    /// The hook failed to apply.
    case failed
    
}

fileprivate enum HookTarget {
    case `class`(AnyClass)
    case object(AnyObject)
}
