import ObjectiveC

final class AnyHookStrategy {
    
    init(replacementIMP: IMP) {
        self.replacementIMP = replacementIMP
    }
    
    /// The replacement implementation used to interpose the method, created during hook setup.
    let replacementIMP: IMP
    
    /// The original method implementation, captured when the hook is applied.
    var originalIMP: IMP?
    
}
