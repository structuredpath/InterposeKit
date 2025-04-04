import ObjectiveC

public enum HookScope {
    
    /// The scope that targets a method on a class type (instance or class method).
    case `class`(MethodKind)
    
    /// The scope that targets a specific object instance.
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
