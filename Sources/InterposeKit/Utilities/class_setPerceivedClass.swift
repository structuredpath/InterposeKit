import ObjectiveC

/// Overrides the `class` method on a class and its metaclass to return a perceived class.
///
/// This affects both instance-level and class-level calls to `[object class]` or `[Class class]`,
/// making the object appear as if it is an instance of `perceivedClass`.
///
/// This does **not** change the actual `isa` pointer or affect dynamic dispatch. It simply
/// overrides how the object and class **report** their type.
///
/// - Parameters:
///   - targetClass: The class whose `class` method should be overridden.
///   - perceivedClass: The class it should appear to be.
internal func class_setPerceivedClass(
    for targetClass: AnyClass,
    to perceivedClass: AnyClass
) {
    let selector = Selector((("class")))
    
    let impBlock: @convention(block) (AnyObject) -> AnyClass = { _ in perceivedClass }
    let imp = imp_implementationWithBlock(impBlock)
    
    // Objective-C type encoding: "#@:"
    // - # → return type is Class
    // - @ → first parameter is 'self' (id)
    // - : → second parameter is '_cmd' (SEL)
    let encoding = UnsafeRawPointer(("#@:" as StaticString).utf8Start)
        .assumingMemoryBound(to: CChar.self)
    
    _ = class_replaceMethod(targetClass, selector, imp, encoding)
    _ = class_replaceMethod(object_getClass(targetClass), selector, imp, encoding)
}
