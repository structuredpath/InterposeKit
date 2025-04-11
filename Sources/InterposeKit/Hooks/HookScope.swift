import ObjectiveC

/// Defines what the scope of a hook—either a class (with method kind) or a specific object.
/// This complements the class and selector when setting up a hook.
public enum HookScope {
    
    /// The scope that targets a method on a class type (instance or class method).
    case `class`(MethodKind)
    
    /// The scope that targets a specific object.
    case object(NSObject)
    
}

extension HookScope {
    
    /// Returns the kind of the method targeted by the hook scope.
    public var methodKind: MethodKind {
        switch self {
        case .class(let methodKind):
            return methodKind
        case .object:
            return .instance
        }
    }
    
}
