import ObjectiveC

final class AnyHookStrategy {
    
    init(replacementIMP: IMP) {
        self.replacementIMP = replacementIMP
    }
    
    let replacementIMP: IMP
    
}
