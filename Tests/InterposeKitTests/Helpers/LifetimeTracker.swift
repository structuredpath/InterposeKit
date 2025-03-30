final class LifetimeTracker {
    
    init(onDeinit: @escaping () -> Void) {
        self.onDeinit = onDeinit
    }
    
    private let onDeinit: () -> Void
    
    func keep() {}
    
    deinit {
        self.onDeinit()
    }
    
}
