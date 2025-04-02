import ObjectiveC

/// Returns the class of an object.
///
/// - Parameter object: A non-nil object to inspect.
/// - Returns: The class of which `object` is an instance.
internal func object_getClass(_ object: AnyObject) -> AnyClass {
    if let `class` = ObjectiveC.object_getClass(object as Any?) {
        return `class`
    } else {
        fatalError("Expected object_getClass(…) to return a class for non-nil object \(object).")
    }
}
