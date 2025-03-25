import ObjectiveC

protocol HookStrategy: AnyObject {
    
    /// The replacement implementation used to interpose the method, created during hook setup.
    var replacementIMP: IMP { get }
    
    /// The original method implementation, captured when the hook is applied.
    var originalIMP: IMP? { get set }
    
}

final class AnyHookStrategy: HookStrategy {
    
    init(replacementIMP: IMP) {
        self.replacementIMP = replacementIMP
    }
    
    let replacementIMP: IMP
    var originalIMP: IMP?
    
}
