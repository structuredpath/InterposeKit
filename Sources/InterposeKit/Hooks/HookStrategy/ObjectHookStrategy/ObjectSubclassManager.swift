import Foundation

internal enum ObjectSubclassManager {
    
    // ============================================================================ //
    // MARK: Getting Installed Subclass
    // ============================================================================ //
    
    internal static func installedSubclass(
        for object: NSObject
    ) -> AnyClass? {
        let actualClass: AnyClass = object_getClass(object)
        return self.isDynamicSubclass(actualClass) ? actualClass : nil
    }
    
    internal static func hasInstalledSubclass(_ object: NSObject) -> Bool {
        let actualClass: AnyClass = object_getClass(object)
        return self.isDynamicSubclass(actualClass)
    }
    
    private static func isDynamicSubclass(_ class: AnyClass) -> Bool {
        NSStringFromClass(`class`).hasPrefix(self.namePrefix)
    }
    
    // ============================================================================ //
    // MARK: Installing & Uninstalling
    // ============================================================================ //
    
    internal static func ensureSubclassInstalled(
        for object: NSObject
    ) throws -> AnyClass {
        // If there is a dynamic subclass already installed on the object, reuse it straightaway.
        if let installedSubclass = self.installedSubclass(for: object) {
            Interpose.log({
                let subclassName = NSStringFromClass(installedSubclass)
                let objectAddress = String(format: "%p", object)
                return "Reused subclass: \(subclassName) for object \(objectAddress)"
            }())
            
            return installedSubclass
        }
        
        // Otherwise, create a dynamic subclass by generating a unique name and registering it
        // with the runtime.
        let subclass: AnyClass = try self.makeSubclass(for: object)
        
        // Finally, set the created class on the object.
        let previousClass: AnyClass? = object_setClass(object, subclass)
        
        Interpose.log({
            let subclassName = NSStringFromClass(subclass)
            let objectAddress = String(format: "%p", object)
            var message = "Created subclass: \(subclassName) for object \(objectAddress)"
            
            if let previousClass {
                message += " (previously: \(NSStringFromClass(previousClass)))"
            }
            
            return message
        }())
        
        return subclass
    }
    
    internal static func uninstallSubclass(
        for object: NSObject
    ) {
        // Get the InterposeKit-managed dynamic subclass installed on the object.
        guard let dynamicSubclass = self.installedSubclass(for: object) else { return }
        
        // Retrieve the original class (superclass of the dynamic subclass) we want to restore
        // the object to.
        guard let originalClass = class_getSuperclass(dynamicSubclass) else { return }
        
        // Restore the object’s class to its original class.
        object_setClass(object, originalClass)
        
        Interpose.log({
            let subclassName = NSStringFromClass(dynamicSubclass)
            let originalClassName = NSStringFromClass(originalClass)
            let objectAddress = String(format: "%p", object)
            return "Removed subclass: \(subclassName), restored \(originalClassName) on object \(objectAddress)"
        }())
        
        // Dispose of the dynamic subclass.
        //
        // This is safe to call here because all hooks have been reverted. Unfortunately, we can’t
        // validate this explicitly, as `objc_disposeClassPair(...)` offers no feedback mechanism
        // and will silently fail if the subclass is still in use.
        objc_disposeClassPair(dynamicSubclass)
    }
    
    // ============================================================================ //
    // MARK: Subclass Generation
    // ============================================================================ //
    
    private static func makeSubclass(
        for object: NSObject
    ) throws -> AnyClass {
        let actualClass: AnyClass = object_getClass(object)
        let perceivedClass: AnyClass = type(of: object)
        
        let subclassName = self.uniqueSubclassName(for: perceivedClass)
        
        return try subclassName.withCString { cString in
            // Attempt to allocate a new subclass that inherits from the object’s actual class.
            guard let subclass: AnyClass = objc_allocateClassPair(actualClass, cString, 0) else {
                throw InterposeError.subclassCreationFailed(
                    subclassName: subclassName,
                    object: object
                )
            }
            
            // Set the perceived class to make the runtime report the original type.
            class_setPerceivedClass(for: subclass, to: perceivedClass)
            
            // Register the subclass with the runtime.
            objc_registerClassPair(subclass)
            
            return subclass
        }
    }
    
    /// Constructs a unique subclass name for the given perceived class.
    ///
    /// Subclass names must be globally unique to avoid registration conflicts. Earlier versions
    /// used random UUIDs, which guaranteed uniqueness but resulted in long and noisy names.
    /// We then considered using the object’s memory address, but since addresses can be reused
    /// during the lifetime of a process, this led to potential conflicts and flaky test behavior.
    ///
    /// The final approach uses a global incrementing counter to ensure uniqueness without relying
    /// on randomness or memory layout. This results in shorter, more readable names that are safe
    /// across repeated test runs and stable in production.
    private static func uniqueSubclassName(
        for perceivedClass: AnyClass
    ) -> String {
        let className = NSStringFromClass(perceivedClass)
        
        let counterSuffix: String = self.subclassCounter.withValue { counter in
            counter &+= 1
            return String(format: "%04llx", counter)
        }
        
        return "\(self.namePrefix)_\(className)_\(counterSuffix)"
    }
    
    /// The prefix used for all dynamically created subclass names.
    private static let namePrefix = "InterposeKit"
    
    /// A lock-isolated global counter for generating unique subclass name suffixes.
    private static let subclassCounter = LockIsolated<UInt64>(0)
    
}
