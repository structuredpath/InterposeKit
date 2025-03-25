import ObjectiveC

protocol _HookStrategy: AnyObject {
    
    /// The replacement implementation used to interpose the method, created during hook setup.
    var replacementIMP: IMP { get }
    
    /// The original method implementation, captured when the hook is applied.
    var originalIMP: IMP? { get }
    
}

protocol HookStrategy<MethodSignature>: _HookStrategy {
    
    associatedtype MethodSignature
    
}

final class DummyHookStrategy<MethodSignature>: HookStrategy {
    
    init(replacementIMP: IMP) {
        self.replacementIMP = replacementIMP
    }
    
    let replacementIMP: IMP
    var originalIMP: IMP?
    
}
