import Foundation
import ITKSuperBuilder

class InterposeSubclass {

    private enum Constants {
        static let subclassSuffix = "InterposeKit_"
    }

    /// Subclass that we create on the fly
    private(set) var dynamicClass: AnyClass

    /// If the class has been altered (e.g. via NSKVONotifying_ KVO logic)
    /// then perceived and actual class don't match.
    ///
    /// Making KVO and Object-based hooking work at the same time is difficult.
    /// If we make a dynamic subclass over KVO, invalidating the token crashes in cache_getImp.
    init(object: AnyObject) throws {
        let dynamicClass: AnyClass = try { () throws -> AnyClass in
            if let dynamicClass = Self.getExistingSubclass(object: object) {
                return dynamicClass
            }
            
            return try Self.createSubclass(object: object)
        }()
        
        self.dynamicClass = dynamicClass
    }

    private static func createSubclass(object: AnyObject) throws -> AnyClass {
        let perceivedClass: AnyClass = type(of: object)
        let actualClass: AnyClass = object_getClass(object)!

        let className = NSStringFromClass(perceivedClass)
        // Right now we are wasteful. Might be able to optimize for shared IMP?
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let subclassName = Constants.subclassSuffix + className + uuid

        let subclass: AnyClass? = subclassName.withCString { cString in
            // swiftlint:disable:next force_cast
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

    /// We need to reuse a dynamic subclass if the object already has one.
    private static func getExistingSubclass(object: AnyObject) -> AnyClass? {
        let actualClass: AnyClass = object_getClass(object)!
        if NSStringFromClass(actualClass).hasPrefix(Constants.subclassSuffix) {
            return actualClass
        }
        return nil
    }

    func addSuperTrampoline(selector: Selector) {
        do {
            try ITKSuperBuilder.addSuperInstanceMethod(to: dynamicClass, selector: selector)

            let imp = class_getMethodImplementation(dynamicClass, selector)!
            Interpose.log("Added super for -[\(dynamicClass).\(selector)]: \(imp)")
        } catch {
            Interpose.log("Failed to add super implementation to -[\(dynamicClass).\(selector)]: \(error)")
        }
    }
}
