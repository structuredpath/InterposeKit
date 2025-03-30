import InterposeKit
import XCTest

fileprivate class ExampleClass: NSObject {
    @objc static dynamic func doSomethingStatic() {}
    @objc dynamic func doSomething() {}
    @objc dynamic var intValue: Int { 1 }
    @objc dynamic var arrayValue: [String] { ["superclass"] }
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
                1 + hook.original(self, hook.selector)
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
                1 + hook.original(self, hook.selector)
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
                1 + hook.original(self, hook.selector)
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
        XCTAssertEqual(object.arrayValue, ["superclass", "subclass"])
        
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
        XCTAssertEqual(object.arrayValue, ["superclass", "superclass.hook", "subclass"])
        
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
        
        XCTAssertEqual(object.arrayValue, ["superclass", "superclass.hook", "subclass", "subclass.hook"])
        
        try superclassHook.revert()
        XCTAssertEqual(object.arrayValue, ["superclass", "subclass", "subclass.hook"])
        
        try subclassHook.revert()
        XCTAssertEqual(object.arrayValue, ["superclass", "subclass"])
    }
    
    func testMultipleHooks() throws {
        let object = ExampleClass()
        XCTAssertEqual(object.arrayValue, ["superclass"])
        
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
        XCTAssertEqual(object.arrayValue, ["superclass", "hook1"])
        
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
        XCTAssertEqual(object.arrayValue, ["superclass", "hook1", "hook2"])
        
        // For now, reverting works only in the opposite order. Reverting hook1 before hook2
        // would throw `revertCorrupted(…)` error.
        try hook2.revert()
        XCTAssertEqual(object.arrayValue, ["superclass", "hook1"])
        
        try hook1.revert()
        XCTAssertEqual(object.arrayValue, ["superclass"])
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
                selector: Selector(("doSomethingNotFound"))
            )
        )
    }
    
    func testValidationFailure_methodNotFound_classMethod() throws {
        XCTAssertThrowsError(
            try Interpose.prepareHook(
                on: ExampleClass.self,
                for: #selector(ExampleClass.doSomethingStatic),
                methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
                hookSignature: (@convention(block) (NSObject) -> Void).self
            ) { hook in
                return { `self` in }
            },
            expected: InterposeError.methodNotFound(
                class: ExampleClass.self,
                selector: #selector(ExampleClass.doSomethingStatic)
            )
        )
    }
    
    func testValidationFailure_methodNotDirectlyImplemented() throws {
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
                selector: #selector(ExampleClass.doSomething)
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
                selector: #selector(ExampleClass.doSomething),
                imp: externalIMP
            )
        )
        
        XCTAssertEqual(hook.state, .failed)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Failed hook for -\[ExampleClass doSomething\]$"#
        )
    }
    
    func testCleanup_implementationPreserved() throws {
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
    
    func testCleanup_implementationDeallocated() throws {
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
