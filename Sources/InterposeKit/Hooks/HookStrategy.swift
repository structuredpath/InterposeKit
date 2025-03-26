import ObjectiveC

protocol HookStrategy: AnyObject, CustomDebugStringConvertible {
    
    /// The replacement implementation used to interpose the method, created during hook setup.
    var replacementIMP: IMP { get }
    
    /// The original method implementation, captured when the hook is applied.
    var originalIMP: IMP? { get }
    
}

final class DummyHookStrategy<MethodSignature>: HookStrategy {
    
    init(replacementIMP: IMP) {
        self.replacementIMP = replacementIMP
    }
    
    let replacementIMP: IMP
    var originalIMP: IMP?
    
}

extension DummyHookStrategy: CustomDebugStringConvertible {
    var debugDescription: String { "" }
}
