import Foundation

internal enum ObjectSubclassManager {
    
    internal static func installedSubclass(
        for object: NSObject
    ) -> AnyClass? {
        let actualClass: AnyClass = object_getClass(object)
        let hasPrefix = NSStringFromClass(actualClass).hasPrefix(self.namePrefix)
        return hasPrefix ? actualClass : nil
    }
    
    internal static func ensureSubclassInstalled(
        for object: NSObject
    ) throws -> AnyClass {
        // If there is a dynamic subclass already installed on the object, reuse it straightaway.
        if let installedSubclass = self.installedSubclass(for: object) {
            return installedSubclass
        }
        
        let subclass: AnyClass = try self.makeSubclass(for: object)
        object_setClass(object, subclass)
        
        let oldName = NSStringFromClass(class_getSuperclass(object_getClass(object)!)!)
        Interpose.log("Generated \(NSStringFromClass(subclass)) for object (was: \(oldName))")
        
        return subclass
    }
    
    private static func makeSubclass(
        for object: NSObject
    ) throws -> AnyClass {
        let actualClass: AnyClass = object_getClass(object)
        let perceivedClass: AnyClass = type(of: object)
        
        let subclassName = self.uniqueSubclassName(
            for: object,
            perceivedClass: perceivedClass
        )
        
        return try subclassName.withCString { cString in
            // ???
            if let existingClass = objc_getClass(cString) as? AnyClass {
                print("Existing", subclassName)
                return existingClass
            }
            
            guard let subclass: AnyClass = objc_allocateClassPair(actualClass, cString, 0) else {
                throw InterposeError.failedToAllocateClassPair(
                    class: perceivedClass,
                    subclassName: subclassName
                )
            }
            
            class_setPerceivedClass(for: subclass, to: perceivedClass)
            objc_registerClassPair(subclass)
            
            return subclass
        }
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
