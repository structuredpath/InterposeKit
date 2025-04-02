import Foundation

internal enum InterposeSubclass {
    
    internal static func dynamicSubclass(
        for object: NSObject
    ) throws -> AnyClass {
        // Reuse the subclass if already installed on the object.
        if let installedSubclass = self.installedDynamicSubclass(for: object) {
            return installedSubclass
        }
        
        return try self.makeDynamicSubclass(for: object)
    }
    
    internal static func installedDynamicSubclass(
        for object: NSObject
    ) -> AnyClass? {
        let actualClass: AnyClass = object_getClass(object)
        if NSStringFromClass(actualClass).hasPrefix(self.namePrefix) {
            return actualClass
        }
        return nil
    }
    
    private static func makeDynamicSubclass(
        for object: NSObject
    ) throws -> AnyClass {
        let perceivedClass: AnyClass = type(of: object)
        let actualClass: AnyClass = object_getClass(object)
        
        let subclassName = self.uniqueSubclassName(
            for: object,
            perceivedClass: perceivedClass
        )
        
        let subclass: AnyClass? = subclassName.withCString { cString in
            if let existingClass = objc_getClass(cString) as! AnyClass? {
                return existingClass
            } else {
                guard let subclass: AnyClass = objc_allocateClassPair(actualClass, cString, 0) else { return nil }
                class_setPerceivedClass(for: subclass, to: perceivedClass)
                objc_registerClassPair(subclass)
                return subclass
            }
        }
        
        guard let nnSubclass = subclass else {
            throw InterposeError.failedToAllocateClassPair(class: perceivedClass, subclassName: subclassName)
        }
        
        object_setClass(object, nnSubclass)
        let oldName = NSStringFromClass(class_getSuperclass(object_getClass(object)!)!)
        Interpose.log("Generated \(NSStringFromClass(nnSubclass)) for object (was: \(oldName))")
        return nnSubclass
    }
    
    /// Constructs a unique subclass name for a specific object and its perceived class.
    ///
    /// Previously, subclass names used random UUIDs to ensure uniqueness. Since each dynamic
    /// subclass is tied to a single concrete object, we now use the object’s memory address
    /// instead. This eliminates randomness while still guaranteeing unique subclass names,
    /// which is necessary when hooking multiple objects of the same class.
    private static func uniqueSubclassName(
        for object: NSObject,
        perceivedClass: AnyClass
    ) -> String {
        let className = NSStringFromClass(perceivedClass)
        let pointer = Unmanaged.passUnretained(object).toOpaque()
        let objectAddress = UInt(bitPattern: pointer)
        let pointerWidth = MemoryLayout<UInt>.size * 2
        return "\(self.namePrefix)_\(className)_\(String(format: "%0\(pointerWidth)llx", objectAddress))"
    }
    
    /// The prefix to use in names of dynamically created subclasses.
    private static let namePrefix = "InterposeKit"
    
}

/// If the class has been altered (e.g. via NSKVONotifying_ KVO logic)
/// then perceived and actual class don't match.
///
/// Making KVO and Object-based hooking work at the same time is difficult.
/// If we make a dynamic subclass over KVO, invalidating the token crashes in cache_getImp.
