import ObjectiveC

public enum InterposeError: Error {
    
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
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch lhs {
        case let .methodNotFound(lhsClass, lhsSelector):
            switch rhs {
            case let .methodNotFound(rhsClass, rhsSelector):
                return lhsClass == rhsClass && lhsSelector == rhsSelector
            default:
                return false
            }
            
        case let .methodNotDirectlyImplemented(lhsClass, lhsSelector):
            switch rhs {
            case let .methodNotDirectlyImplemented(rhsClass, rhsSelector):
                return lhsClass == rhsClass && lhsSelector == rhsSelector
            default:
                return false
            }
            
        case let .implementationNotFound(lhsClass, lhsSelector):
            switch rhs {
            case let .implementationNotFound(rhsClass, rhsSelector):
                return lhsClass == rhsClass && lhsSelector == rhsSelector
            default:
                return false
            }
            
        case let .revertCorrupted(lhsClass, lhsSelector, lhsIMP):
            switch rhs {
            case let .revertCorrupted(rhsClass, rhsSelector, rhsIMP):
                return lhsClass == rhsClass && lhsSelector == rhsSelector && lhsIMP == rhsIMP
            default:
                return false
            }
            
        case let .subclassCreationFailed(lhsName, lhsObject):
            switch rhs {
            case let .subclassCreationFailed(rhsName, rhsObject):
                return lhsName == rhsName && lhsObject === rhsObject
            default:
                return false
            }
            
        case let .kvoDetected(lhsObject):
            switch rhs {
            case let .kvoDetected(rhsObject):
                return lhsObject === rhsObject
            default:
                return false
            }
            
        case let .unexpectedDynamicSubclass(lhsObject, lhsClass):
            switch rhs {
            case let .unexpectedDynamicSubclass(rhsObject, rhsClass):
                return lhsObject === rhsObject && lhsClass == rhsClass
            default:
                return false
            }
            
        case let .unknownError(lhsReason):
            switch rhs {
            case let .unknownError(rhsReason):
                return lhsReason == rhsReason
            default:
                return false
            }
        }
    }
}
