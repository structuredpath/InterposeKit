import ObjectiveC

internal enum ObjectHookRegistry {
    
    /// Associates the given object hook handle with the block-based IMP in a weak fashion.
    internal static func register(
        _ handle: ObjectHookHandle,
        for imp: IMP
    ) {
        guard let block = imp_getBlock(imp) else {
            Interpose.fail("IMP does not point to a block.")
        }
        
        objc_setAssociatedObject(
            block,
            &ObjectHookRegistryKey,
            WeakReference(handle),
            .OBJC_ASSOCIATION_RETAIN
        )
    }
    
    /// Returns the object hook handle previously associated with the given block-based IMP,
    /// if still alive.
    internal static func handle(for imp: IMP) -> ObjectHookHandle? {
        guard let block = imp_getBlock(imp) else { return nil }
        
        guard let reference = objc_getAssociatedObject(
            block,
            &ObjectHookRegistryKey
        ) as? WeakReference<ObjectHookHandle> else { return nil }
        
        return reference.object
    }
    
}

fileprivate var ObjectHookRegistryKey: UInt8 = 0

fileprivate class WeakReference<T: AnyObject>: NSObject {
    
    fileprivate init(_ object: T?) {
        self._object = object
    }
    
    private weak var _object: T?
    
    fileprivate var object: T? {
        return self._object
    }
    
}
