import Foundation

public enum InterposeError: LocalizedError {
    
    /// No instance method found for the selector on the specified class.
    ///
    /// This typically occurs when mistyping a stringified selector or attempting to interpose
    /// a class method, which is not supported.
    case methodNotFound(
        class: AnyClass,
        selector: Selector
    )
    
    /// The method for the selector is not directly implemented on the specified class
    /// but inherited from a superclass.
    ///
    /// Class-based interposing only supports instance methods implemented directly by the class
    /// itself. This restriction ensures safe reverting via `revert()`, which cannot remove
    /// dynamically added methods.
    ///
    /// To interpose this method, consider hooking the superclass that provides the implementation,
    /// or use object-based hooking on a specific instance instead.
    case methodNotDirectlyImplemented(
        class: AnyClass,
        selector: Selector
    )

    /// No implementation found for the method matching the specified selector on the class.
    ///
    /// This should not occur under normal conditions and may indicate an invalid or misconfigured
    /// runtime state.
    case implementationNotFound(
        class: AnyClass,
        selector: Selector
    )
    
    /// The method implementation was changed externally after the hook was applied, and the revert
    /// operation has removed that unexpected implementation.
    ///
    /// This typically indicates that another system modified the method after interposing.
    /// In such cases, `Hook.revert()` is unsafe and should be avoided.
    case revertCorrupted(
        class: AnyClass,
        selector: Selector,
        imp: IMP?
    )
    
    /// Failed to create a dynamic subclass for the given object.
    ///
    /// This can occur if the desired subclass name is already in use. While InterposeKit
    /// generates globally unique subclass names using an internal counter, a name collision may
    /// still happen if another system has registered a class with the same name earlier during
    /// the process lifetime.
    case subclassCreationFailed(
        subclassName: String,
        object: NSObject
    )
    
    /// Detected Key-Value Observing on the object while applying or reverting a hook.
    ///
    /// The KVO mechanism installs its own dynamic subclass at runtime but does not support
    /// additional method overrides. Applying or reverting hooks on an object under KVO can lead
    /// to crashes in the Objective-C runtime, so such operations are explicitly disallowed.
    ///
    /// It is safe to start observing an object *after* it has been hooked, but not the other way
    /// around. Once KVO is active, reverting an existing hook is also considered unsafe.
    case kvoDetected(object: NSObject)
    
    /// The object uses a dynamic subclass that was not installed by InterposeKit.
    ///
    /// This typically indicates interference from another runtime system, such as method
    /// swizzling libraries (like [Aspects](https://github.com/steipete/Aspects)). Similar to KVO,
    /// such subclasses bypass normal safety checks. Hooking is disallowed in this case to
    /// avoid crashes.
    ///
    /// - Note: Use `NSStringFromClass` to print class names accurately. Swift’s default
    ///   formatting may reflect the perceived, not the actual runtime class.
    case unexpectedDynamicSubclass(
        object: NSObject,
        actualClass: AnyClass
    )

    /// Generic failure
    case unknownError(_ reason: String)
}

extension InterposeError: Equatable {
    // Lazy equating via string compare
    public static func == (lhs: InterposeError, rhs: InterposeError) -> Bool {
        return lhs.errorDescription == rhs.errorDescription
    }

    public var errorDescription: String {
        switch self {
        case .methodNotFound(let `class`, let selector):
            return "Method not found: -[\(`class`) \(selector)]"
        case .methodNotDirectlyImplemented(let `class`, let selector):
            return "Method not directly implemented: -[\(`class`) \(selector)]"
        case .implementationNotFound(let `class`, let selector):
            return "Implementation not found: -[\(`class`) \(selector)]"
        case .revertCorrupted(let `class`, let selector, let IMP):
            return "Unexpected Implementation in -[\(`class`) \(selector)]: \(String(describing: IMP))"
        case .subclassCreationFailed(let subclassName, let object):
            return "Failed to allocate class pair: \(object), \(subclassName)"
        case .kvoDetected(let obj):
            return "Unable to hook object that uses Key Value Observing: \(obj)"
        case .unexpectedDynamicSubclass(let obj, let actualClass):
            return "Unable to hook \(type(of: obj)) posing as \(NSStringFromClass(actualClass))/"
        case .unknownError(let reason):
            return reason
        }
    }

    @discardableResult func log() -> InterposeError {
        Interpose.log(self.errorDescription)
        return self
    }
}
