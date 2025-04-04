public enum MethodKind: Equatable {
    
    /// An instance method, e.g. `-[MyClass doSomething]`.
    case instance
    
    /// A class method, e.g. `+[MyClass doSomething]`.
    case `class`
    
}

extension MethodKind {
    
    /// Returns the Objective-C method prefix symbol for this kind, `-` for instance methods
    /// and `+` for class methods.
    internal var symbolPrefix: String {
        switch self {
        case .instance:
            return "-"
        case .class:
            return "+"
        }
    }
    
}
