import InterposeKit
import XCTest

fileprivate class ExampleClass: NSObject {
    @objc static dynamic func doSomethingStatic() {}
    @objc static dynamic let intValueStatic = 1
    @objc dynamic func doSomething() {}
    @objc dynamic var intValue = 1
    @objc dynamic var arrayValue: [String] { ["base"] }
}

fileprivate class ExampleSubclass: ExampleClass {
    override var arrayValue: [String] {
        super.arrayValue + ["subclass"]
    }
}

final class ClassHookTests: XCTestCase {
    
    override func setUpWithError() throws {
        Interpose.isLoggingEnabled = true
    }
    
    func testLifecycle_applyHook() throws {
        let hook = try Interpose.applyHook(
            on: ExampleClass.self,
            for: #selector(getter: ExampleClass.intValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> Int).self,
            hookSignature: (@convention(block) (NSObject) -> Int).self
        ) { hook in
            return { `self` in
                hook.original(self, hook.selector) + 1
            }
        }
        
        XCTAssertEqual(ExampleClass().intValue, 2)
        XCTAssertEqual(hook.state, .active)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Active hook for -\[ExampleClass intValue\] \(originalIMP: 0x[0-9a-fA-F]+\)$"#
        )
        
        try hook.revert()
        
        XCTAssertEqual(ExampleClass().intValue, 1)
        XCTAssertEqual(hook.state, .pending)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Pending hook for -\[ExampleClass intValue\]$"#
        )
    }
    
    func testLifecycle_prepareHook() throws {
        let hook = try Interpose.prepareHook(
            on: ExampleClass.self,
            for: #selector(getter: ExampleClass.intValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> Int).self,
            hookSignature: (@convention(block) (NSObject) -> Int).self
        ) { hook in
            return { `self` in
                hook.original(self, hook.selector) + 1
            }
        }
        
        XCTAssertEqual(ExampleClass().intValue, 1)
        XCTAssertEqual(hook.state, .pending)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Pending hook for -\[ExampleClass intValue\]$"#
        )
        
        try hook.apply()
        
        XCTAssertEqual(ExampleClass().intValue, 2)
        XCTAssertEqual(hook.state, .active)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Active hook for -\[ExampleClass intValue\] \(originalIMP: 0x[0-9a-fA-F]+\)$"#
        )
        
        try hook.revert()
        
        XCTAssertEqual(ExampleClass().intValue, 1)
        XCTAssertEqual(hook.state, .pending)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Pending hook for -\[ExampleClass intValue\]$"#
        )
    }
    
    func testIdempotentApplyAndRevert() throws {
        let object = ExampleClass()
        
        let hook = try Interpose.prepareHook(
            on: ExampleClass.self,
            for: #selector(getter: ExampleClass.intValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> Int).self,
            hookSignature: (@convention(block) (NSObject) -> Int).self
        ) { hook in
            return { `self` in
                hook.original(self, hook.selector) + 1
            }
        }
        
        XCTAssertEqual(object.intValue, 1)
        XCTAssertEqual(hook.state, .pending)
        
        try hook.apply()
        try hook.apply() // noop
        
        XCTAssertEqual(object.intValue, 2)
        XCTAssertEqual(hook.state, .active)
        
        try hook.revert()
        try hook.revert() // noop
        
        XCTAssertEqual(object.intValue, 1)
        XCTAssertEqual(hook.state, .pending)
        
        try hook.apply()
        
        XCTAssertEqual(object.intValue, 2)
        XCTAssertEqual(hook.state, .active)
        
        try hook.revert()
        
        XCTAssertEqual(object.intValue, 1)
        XCTAssertEqual(hook.state, .pending)
    }
    
    func testSubclassOverride() throws {
        let object = ExampleSubclass()
        XCTAssertEqual(object.arrayValue, ["base", "subclass"])
        
        let superclassHook = try Interpose.applyHook(
            on: ExampleClass.self,
            for: #selector(getter: ExampleClass.arrayValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> [String]).self,
            hookSignature: (@convention(block) (NSObject) -> [String]).self
        ) { hook in
            return { `self` in
                return hook.original(self, hook.selector) + ["superclass.hook"]
            }
        }
        XCTAssertEqual(object.arrayValue, ["base", "superclass.hook", "subclass"])
        
        let subclassHook = try Interpose.applyHook(
            on: ExampleSubclass.self,
            for: #selector(getter: ExampleClass.arrayValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> [String]).self,
            hookSignature: (@convention(block) (NSObject) -> [String]).self
        ) { hook in
            return { `self` in
                return hook.original(self, hook.selector) + ["subclass.hook"]
            }
        }
        
        XCTAssertEqual(object.arrayValue, ["base", "superclass.hook", "subclass", "subclass.hook"])
        
        try superclassHook.revert()
        XCTAssertEqual(object.arrayValue, ["base", "subclass", "subclass.hook"])
        
        try subclassHook.revert()
        XCTAssertEqual(object.arrayValue, ["base", "subclass"])
    }
    
    func testMultipleHooks() throws {
        let object = ExampleClass()
        XCTAssertEqual(object.arrayValue, ["base"])
        
        let hook1 = try Interpose.applyHook(
            on: ExampleClass.self,
            for: #selector(getter: ExampleClass.arrayValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> [String]).self,
            hookSignature: (@convention(block) (NSObject) -> [String]).self
        ) { hook in
            return { `self` in
                return hook.original(self, hook.selector) + ["hook1"]
            }
        }
        XCTAssertEqual(object.arrayValue, ["base", "hook1"])
        
        let hook2 = try Interpose.applyHook(
            on: ExampleClass.self,
            for: #selector(getter: ExampleClass.arrayValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> [String]).self,
            hookSignature: (@convention(block) (NSObject) -> [String]).self
        ) { hook in
            return { `self` in
                return hook.original(self, hook.selector) + ["hook2"]
            }
        }
        XCTAssertEqual(object.arrayValue, ["base", "hook1", "hook2"])
        
        // For now, reverting works only in the opposite order. Reverting hook1 before hook2
        // would throw `revertCorrupted(…)` error.
        try hook2.revert()
        XCTAssertEqual(object.arrayValue, ["base", "hook1"])
        
        try hook1.revert()
        XCTAssertEqual(object.arrayValue, ["base"])
    }
    
    func testClassMethod() throws {
        let hook = try Interpose.prepareHook(
            on: ExampleClass.self,
            for: #selector(getter: ExampleClass.intValueStatic),
            methodKind: .class,
            methodSignature: (@convention(c) (ExampleClass.Type, Selector) -> Int).self,
            hookSignature: (@convention(block) (ExampleClass.Type) -> Int).self
        ) { hook in
            return { `self` in 2 }
        }
        
        XCTAssertEqual(ExampleClass.intValueStatic, 1)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Pending hook for \+\[ExampleClass intValueStatic\]$"#
        )
        
        try hook.apply()
        XCTAssertEqual(ExampleClass.intValueStatic, 2)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Active hook for \+\[ExampleClass intValueStatic\] \(originalIMP: 0x[0-9a-fA-F]+\)$"#
        )
        
        try hook.revert()
        XCTAssertEqual(ExampleClass.intValueStatic, 1)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Pending hook for \+\[ExampleClass intValueStatic\]$"#
        )
    }
    
    func testValidationFailure_methodNotFound_nonExistent() throws {
        XCTAssertThrowsError(
            try Interpose.prepareHook(
                on: ExampleClass.self,
                for: Selector(("doSomethingNotFound")),
                methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
                hookSignature: (@convention(block) (NSObject) -> Void).self
            ) { hook in
                return { `self` in }
            },
            expected: InterposeError.methodNotFound(
                class: ExampleClass.self,
                kind: .instance,
                selector: Selector(("doSomethingNotFound"))
            )
        )
    }
    
    func testValidationFailure_methodNotDirectlyImplemented_instanceMethod() throws {
        XCTAssertThrowsError(
            try Interpose.prepareHook(
                on: ExampleSubclass.self,
                for: #selector(ExampleClass.doSomething),
                methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
                hookSignature: (@convention(block) (NSObject) -> Void).self
            ) { hook in
                return { `self` in }
            },
            expected: InterposeError.methodNotDirectlyImplemented(
                class: ExampleSubclass.self,
                kind: .instance,
                selector: #selector(ExampleClass.doSomething)
            )
        )
    }
    
    func testValidationFailure_methodNotDirectlyImplemented_classMethod() throws {
        XCTAssertThrowsError(
            try Interpose.prepareHook(
                on: ExampleSubclass.self,
                for: #selector(ExampleClass.doSomethingStatic),
                methodKind: .class,
                methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
                hookSignature: (@convention(block) (NSObject) -> Void).self
            ) { hook in
                return { `self` in }
            },
            expected: InterposeError.methodNotDirectlyImplemented(
                class: ExampleSubclass.self,
                kind: .class,
                selector: #selector(ExampleClass.doSomethingStatic)
            )
        )
    }
    
    func testRevertFailure_corrupted() throws {
        let hook = try Interpose.applyHook(
            on: ExampleClass.self,
            for: #selector(ExampleClass.doSomething),
            methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
            hookSignature: (@convention(block) (NSObject) -> Void).self
        ) { hook in
            return { `self` in }
        }
        XCTAssertEqual(hook.state, .active)
        
        // After applying the hook, we swizzle once more externally, putting the hook into a state,
        // in which it cannot restore the original implementation.
        let method = try XCTUnwrap(class_getInstanceMethod(
            ExampleClass.self,
            #selector(ExampleClass.doSomething)
        ))
        
        let externalBlock: @convention(block) (NSObject) -> Void = { _ in }
        let externalIMP = imp_implementationWithBlock(externalBlock)
        
        XCTAssertNotNil(class_replaceMethod(
            ExampleClass.self,
            #selector(ExampleClass.doSomething),
            externalIMP,
            method_getTypeEncoding(method)
        ))
        
        XCTAssertThrowsError(
            try hook.revert(),
            expected: InterposeError.revertCorrupted(
                class: ExampleClass.self,
                kind: .instance,
                selector: #selector(ExampleClass.doSomething),
                imp: externalIMP
            )
        )
        
        XCTAssertEqual(hook.state, .failed)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Failed hook for -\[ExampleClass doSomething\]$"#
        )
        
        XCTAssertThrowsError(
            try hook.revert(),
            expected: InterposeError.hookInFailedState
        )
    }
    
    func testCleanUp_implementationPreserved() throws {
        var deallocated = false
        
        try autoreleasepool {
            let tracker = LifetimeTracker { deallocated = true }
            
            try Interpose.applyHook(
                on: ExampleClass.self,
                for: #selector(ExampleClass.doSomething),
                methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
                hookSignature: (@convention(block) (NSObject) -> Void).self
            ) { hook in
                return { `self` in
                    tracker.keep()
                    return hook.original(self, hook.selector)
                }
            }
        }
        
        XCTAssertFalse(deallocated)
    }
    
    func testCleanUp_implementationDeallocated() throws {
        var deallocated = false
        
        try autoreleasepool {
            let tracker = LifetimeTracker { deallocated = true }
            
            let hook = try Interpose.applyHook(
                on: ExampleClass.self,
                for: #selector(ExampleClass.doSomething),
                methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
                hookSignature: (@convention(block) (NSObject) -> Void).self
            ) { hook in
                return { `self` in
                    tracker.keep()
                    return hook.original(self, hook.selector)
                }
            }
            
            try hook.revert()
        }
        
        XCTAssertTrue(deallocated)
    }
    
}
