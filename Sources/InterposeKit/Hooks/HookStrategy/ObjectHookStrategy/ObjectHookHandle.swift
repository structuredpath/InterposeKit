import ObjectiveC

/// A lightweight handle for an object hook, providing access to the stored original IMP.
///
/// Used internally to manage hook chaining and rewiring. The handle delegates all reads
/// and writes to the `ObjectHookStrategy` through the provided closures.
internal final class ObjectHookHandle {
    
    internal init(
        getOriginalIMP: @escaping () -> IMP?,
        setOriginalIMP: @escaping (IMP?) -> Void
    ) {
        self._getOriginalIMP = getOriginalIMP
        self._setOriginalIMP = setOriginalIMP
    }
    
    private let _getOriginalIMP: () -> IMP?
    private let _setOriginalIMP: (IMP?) -> Void
    
    /// The original IMP stored for the object hook referenced by this handle.
    internal var originalIMP: IMP? {
        get { self._getOriginalIMP() }
        set { self._setOriginalIMP(newValue) }
    }
    
}
