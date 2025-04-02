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

    /// Unable to register subclass for object-based interposing.
    case failedToAllocateClassPair(class: AnyClass, subclassName: String)

    /// Object-based hooking does not work if an object is using KVO.
    /// The KVO mechanism also uses subclasses created at runtime but doesn't check for additional overrides.
    /// Adding a hook eventually crashes the KVO management code so we reject hooking altogether in this case.
    case kvoDetected(AnyObject)

    /// Object is lying about it's actual class metadata.
    /// This usually happens when other swizzling libraries (like Aspects) also interfere with a class.
    /// While this might just work, it's not worth risking a crash, so similar to KVO this case is rejected.
    ///
    /// @note Printing classes in Swift uses the class posing mechanism.
    /// Use `NSClassFromString` to get the correct name.
    case objectPosingAsDifferentClass(AnyObject, actualClass: AnyClass)

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
        case .failedToAllocateClassPair(let `class`, let subclassName):
            return "Failed to allocate class pair: \(`class`), \(subclassName)"
        case .kvoDetected(let obj):
            return "Unable to hook object that uses Key Value Observing: \(obj)"
        case .objectPosingAsDifferentClass(let obj, let actualClass):
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
