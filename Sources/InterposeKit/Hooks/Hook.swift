import ObjectiveC

/// A runtime hook that interposes a single instance method on a class or object.
public final class Hook {
    
    // ============================================================================ //
    // MARK: Initialization
    // ============================================================================ //
    
    internal init<MethodSignature, HookSignature>(
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
    
    /// The effective original implementation of the method being hooked.
    ///
    /// Resolved via the active strategy. If the hook has been applied, it returns a stored
    /// original implementation. Otherwise, it performs a dynamic lookup at runtime.
    ///
    /// Provided to the hook builder via a proxy to enable calls to the original implementation.
    /// This value is dynamic and must not be cached.
    internal var originalIMP: IMP {
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

/// A closure that builds a hook implementation block for a method.
///
/// Receives a proxy to the hook, which provides access to the selector and the original
/// implementation, and returns a block to be installed when the hook is applied.
///
/// `MethodSignature` is the C function type of the original method implementation, typically
/// in the form: `(@convention(c) (AnyObject, Selector, Params…) -> ReturnValue).self`.
///
/// `HookSignature` is the block type used as the replacement, typically in the form:
/// `(@convention(block) (AnyObject, Params…) -> ReturnValue).self`.
public typealias HookBuilder<MethodSignature, HookSignature> = (HookProxy<MethodSignature>) -> HookSignature

/// A lightweight proxy passed to a `HookBuilder`, providing access to the selector and original
/// implementation of the hooked method.
public final class HookProxy<MethodSignature> {
    
    internal init(
        selector: Selector,
        getOriginal: @escaping () -> MethodSignature
    ) {
        self.selector = selector
        self._getOriginal = getOriginal
    }
    
    /// The selector of the method being hooked.
    public let selector: Selector
    
    /// The original method implementation, safe to call from within the hook block.
    public var original: MethodSignature {
        self._getOriginal()
    }
    
    private let _getOriginal: () -> MethodSignature
    
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

internal enum HookTarget {
    case `class`(AnyClass)
    case object(NSObject)
}
