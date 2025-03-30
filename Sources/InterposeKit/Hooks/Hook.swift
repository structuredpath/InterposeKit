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
            let makeHookIMP: () -> IMP = { [weak hook] in
                
                // Hook should never be deallocated when invoking `makeHookIMP()`, as this only
                // happens when installing implementation from within the strategy, which is
                // triggered from a live hook instance.
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
            case .class(let `class`):
                return ClassHookStrategy(
                    class: `class`,
                    selector: selector,
                    makeHookIMP: makeHookIMP
                )
            case .object(let object):
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
        var logComponents = [String]()
        
        switch self.state {
        case .pending:
            logComponents.append("Releasing")
        case .active:
            logComponents.append("Keeping")
        case .failed:
            logComponents.append("Leaking")
        }
        
        logComponents.append("-[\(self.class) \(self.selector)]")
        
        if let hookIMP = self.strategy.appliedHookIMP {
            logComponents.append("IMP: \(hookIMP)")
        }
        
        Interpose.log(logComponents.joined(separator: " "))
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
        
        description.append(" hook for -[\(self.class) \(self.selector)]")
        
        if case .object(let object) = self.scope {
            description.append(" on \(ObjectIdentifier(object))")
        }
        
        if let originalIMP = self.strategy.storedOriginalIMP {
            description.append(" (originalIMP: \(originalIMP))")
        }
        
        return description
    }
}

public enum HookScope {
    
    /// The scope that targets all instances of the class.
    case `class`
    
    /// The scope that targets a specific instance of the class.
    case object(NSObject)
    
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
