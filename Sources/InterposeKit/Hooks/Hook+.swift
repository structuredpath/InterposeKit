import ObjectiveC

public typealias HookBuilder<MethodSignature, HookSignature> = (HookProxy<MethodSignature>) -> HookSignature

public final class HookProxy<MethodSignature> {
    
    internal init(
        selector: Selector,
        originalProvider: @escaping () -> MethodSignature
    ) {
        self.selector = selector
        self.originalProvider = originalProvider
    }
    
    public let selector: Selector
    
    private let originalProvider: () -> MethodSignature
    
    public var original: MethodSignature { self.originalProvider() }
    
}

public enum HookState: Equatable {
    
    /// The hook is ready to be applied.
    case pending
    
    /// The hook has been successfully applied.
    case active
    
    /// The hook failed to apply.
    case failed
    
}
