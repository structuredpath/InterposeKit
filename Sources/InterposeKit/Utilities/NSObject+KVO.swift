import ObjectiveC

extension NSObject {
    internal var isKeyValueObserved: Bool {
        self.value(forKey: "_isKVOA") as? Bool ?? false
    }
}
