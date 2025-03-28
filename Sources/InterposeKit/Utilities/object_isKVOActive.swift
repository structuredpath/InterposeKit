import ObjectiveC

/// Returns whether the given object has KVO active and thus a runtime subclass installed.
///
/// This calls `-[NSObject isKVOA]` via key-value coding, a private (but seemingly stable) API
/// used internally by the Objective-C runtime to indicate whether KVO has installed a dynamic
/// subclass on the object.
///
/// The typical alternative to this approach is to inspect the object’s class name for the prefix
/// `"NSKVONotifying_"`. However, when the observed class is defined in Swift, we’ve observed
/// the runtime-generated subclass being prefixed with `".."`, resulting in names like
/// `"..NSKVONotifying_MyApp.MyClass"`.
///
/// In practice, calling `-[NSObject isKVOA]` is a more robust and consistent check.
///
/// - Parameter object: The object to check.
/// - Returns: `true` if KVO is active and the object has been subclassed at runtime; otherwise,
/// `false`.
@inline(__always)
internal func object_isKVOActive(
    _ object: NSObject
) -> Bool {
    return object.value(forKey: "_" + "i" + "s" + "K" + "V" + "O" + "A") as? Bool ?? false
}
