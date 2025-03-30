import ObjectiveC

/// Returns whether the specified class directly implements an instance method for the given
/// selector, without considering methods inherited from superclasses.
internal func class_implementsInstanceMethod(
    _ class: AnyClass,
    _ selector: Selector
) -> Bool {
    var methodCount: UInt32 = 0
    guard let methodList = class_copyMethodList(`class`, &methodCount) else { return false }
    defer { free(methodList) }
    
    for index in 0..<Int(methodCount) {
        let method = methodList[index]
        if method_getName(method) == selector {
            return true
        }
    }
    
    return false
}
