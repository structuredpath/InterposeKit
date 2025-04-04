import ObjectiveC

/// A runtime hook that interposes a single instance method on a class or object.
public final class Hook {
    
    // ============================================================================ //
    // MARK: Initialization
    // ============================================================================ //
    
    internal init<MethodSignature, HookSignature>(
        target: HookTarget,
        selector: Selector,
        build: @escaping HookBuilder<MethodSignature, HookSignature>
    ) throws {
        self.makeStrategy = { hook in
            // Hook should never be deallocated when invoking `makeHookIMP()`, as this only
            // occurs during strategy installation, which is triggered from a live hook instance.
            //
            // To ensure this, a strong reference cycle is intentionally created when the hook
            // is applied: the strategy installs a block-based IMP (stored in `appliedHookIMP`)
            // that retains a hook proxy, which in turn holds a strong reference to the hook.
            // This keeps the hook alive while it is applied, allowing access to its original
            // implementation.
            //
            // When not applied (i.e. prepared or reverted), `makeHookIMP` captures the hook
            // weakly to avoid premature retention, causing the hook to be deallocated when
            // the client releases it.
            //
            // Reference graph:
            //                          +------------------+
            //                          |      Client      |
            //                          +------------------+
            //                                    |
            //                                    v
            // +------------------+     +------------------+     weak
            // |    HookProxy     |---->|       Hook       |< - - - - - - -+
            // +------------------+     +------------------+               |
            //           ^                        |                        |
            //           |                        v                        |
            //           |              +------------------+     +------------------+
            //           |              |   HookStrategy   |---->|   makeHookIMP    |
            //           |              +------------------+     +------------------+
            //           |                        |
            //           |                        v
            //           |              +------------------+
            //           +--------------|  appliedHookIMP  |
            //                          +------------------+
            let makeHookIMP: () -> IMP = { [weak hook] in
                guard let hook else {
                    Interpose.fail(
                        """
                        Internal inconsistency: Hook instance was deallocated before the hook \
                        implementation could be created.
                        """
                    )
                }
                
                let hookProxy = HookProxy(
                    selector: selector,
                    getOriginal: {
                        unsafeBitCast(
                            hook.originalIMP,
                            to: MethodSignature.self
                        )
                    }
                )
                
                let hookBlock = build(hookProxy)
                let hookIMP = imp_implementationWithBlock(hookBlock)
                return hookIMP
            }
            
            switch target {
            case let .class(`class`, methodKind):
                return ClassHookStrategy(
                    class: `class`,
                    methodKind: methodKind,
                    selector: selector,
                    makeHookIMP: makeHookIMP
                )
            case let .object(object):
                return ObjectHookStrategy(
                    object: object,
                    selector: selector,
                    makeHookIMP: makeHookIMP
                )
            }
        }
        
        try self.strategy.validate()
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
        switch self.state {
        case .pending:
            do {
                try self.strategy.replaceImplementation()
                self.state = .active
            } catch {
                self.state = .failed
                throw error
            }
        case .failed:
            throw InterposeError.hookInFailedState
        case .active:
            return
        }
    }

    /// Reverts the hook, restoring the original method implementation.
    public func revert() throws {
        switch self.state {
        case .active:
            do {
                try self.strategy.restoreImplementation()
                self.state = .pending
            } catch {
                self.state = .failed
                throw error
            }
        case .failed:
            throw InterposeError.hookInFailedState
        case .pending:
            return
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

    /// The strategy responsible for interposing and managing the method implementation.
    ///
    /// Lazily initialized because strategy construction requires `self` to be passed into
    /// the hook proxy when building the hook implementation.
    private lazy var strategy: HookStrategy = { self.makeStrategy(self) }()
    
    /// A closure that creates the strategy powering the hook.
    private let makeStrategy: (Hook) -> HookStrategy
    
    // ============================================================================ //
    // MARK: Deinitialization
    // ============================================================================ //
    
    deinit {
        Interpose.log({
            var components = [String]()
            
            switch self.state {
            case .pending:
                components.append("Releasing")
            case .active:
                components.append("Keeping")
            case .failed:
                components.append("Leaking")
            }
            
            components.append("hook for")
            components.append("-[\(self.class) \(self.selector)]")
            
            if let hookIMP = self.strategy.appliedHookIMP {
                components.append("IMP: \(hookIMP)")
            }
            
            return components.joined(separator: " ")
        }())
    }
    
}

extension Hook: CustomDebugStringConvertible {
    public var debugDescription: String {
        var description = ""
        
        switch self.state {
        case .pending: description += "Pending"
        case .active: description += "Active"
        case .failed: description += "Failed"
        }
        
        let symbolPrefix = self.scope.methodKind.symbolPrefix
        description.append(" hook for \(symbolPrefix)[\(self.class) \(self.selector)]")
        
        if case .object(let object) = self.scope {
            description.append(" on \(Unmanaged.passUnretained(object).toOpaque())")
        }
        
        if let originalIMP = self.strategy.storedOriginalIMP {
            description.append(" (originalIMP: \(originalIMP))")
        }
        
        return description
    }
}

public enum HookState: Equatable {
    
    /// The hook is ready to be applied.
    case pending
    
    /// The hook has been successfully applied.
    case active
    
    /// The hook failed to apply.
    case failed
    
}

/// Represents the target of a hook operation—either a class type or a specific object instance.
internal enum HookTarget {
    
    /// A hook targeting a method defined on a class, either an instance method or a class method.
    case `class`(AnyClass, MethodKind)
    
    /// A hook targeting a method on a specific object instance.
    case object(NSObject)
    
}
