import ObjectiveC

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
