@testable import InterposeKit
import XCTest

fileprivate class ExampleClass: NSObject {
    @objc dynamic var intValue = 1
    @objc dynamic func doSomething() {}
    @objc dynamic var arrayValue: [String] { ["base"] }
}

final class ObjectHookTests: XCTestCase {
    
    override func setUpWithError() throws {
        Interpose.isLoggingEnabled = true
    }
    
    func testLifecycle_applyHook() throws {
        let testObject = ExampleClass()
        let controlObject = ExampleClass()
        
        let hook = try testObject.applyHook(
            for: #selector(getter: ExampleClass.intValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> Int).self,
            hookSignature: (@convention(block) (NSObject) -> Int).self
        ) { hook in
            return { `self` in
                hook.original(self, hook.selector) + 1
            }
        }
        
        XCTAssertEqual(testObject.intValue, 2)
        XCTAssertEqual(controlObject.intValue, 1)
        
        XCTAssertEqual(hook.state, .active)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Active hook for -\[ExampleClass intValue\] on 0x[0-9a-fA-F]+ \(originalIMP: 0x[0-9a-fA-F]+\)$"#
        )
        
        try hook.revert()
        
        XCTAssertEqual(testObject.intValue, 1)
        XCTAssertEqual(controlObject.intValue, 1)
        
        XCTAssertEqual(hook.state, .pending)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Pending hook for -\[ExampleClass intValue\] on 0x[0-9a-fA-F]+$"#
        )
    }
    
    func testMultipleHooks() throws {
        let object = ExampleClass()
        XCTAssertEqual(object.arrayValue, ["base"])
        
        let hook1 = try object.applyHook(
            for: #selector(getter: ExampleClass.arrayValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> [String]).self,
            hookSignature: (@convention(block) (NSObject) -> [String]).self
        ) { hook in
            return { `self` in
                return hook.original(self, hook.selector) + ["hook1"]
            }
        }
        XCTAssertEqual(object.arrayValue, ["base", "hook1"])
        
        let hook2 = try object.applyHook(
            for: #selector(getter: ExampleClass.arrayValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> [String]).self,
            hookSignature: (@convention(block) (NSObject) -> [String]).self
        ) { hook in
            return { `self` in
                return hook.original(self, hook.selector) + ["hook2"]
            }
        }
        XCTAssertEqual(object.arrayValue, ["base", "hook1", "hook2"])
        
        // Unlike with class hooks, we can revert object hooks in the middle of the chain.
        try hook1.revert()
        XCTAssertEqual(object.arrayValue, ["base", "hook2"])
        
        try hook2.revert()
        XCTAssertEqual(object.arrayValue, ["base"])
    }
    
    func testHookOnMultipleObjects() throws {
        let object1 = ExampleClass()
        let object2 = ExampleClass()
        
        XCTAssertEqual(object1.arrayValue, ["base"])
        XCTAssertEqual(object2.arrayValue, ["base"])
        
        XCTAssertEqual(
            NSStringFromClass(object_getClass(object1)),
            NSStringFromClass(object_getClass(object2))
        )
        
        let hook1 = try object1.applyHook(
            for: #selector(getter: ExampleClass.arrayValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> [String]).self,
            hookSignature: (@convention(block) (NSObject) -> [String]).self
        ) { hook in
            return { `self` in
                return hook.original(self, hook.selector) + ["hook1"]
            }
        }
        XCTAssertEqual(object1.arrayValue, ["base", "hook1"])
        XCTAssertEqual(object2.arrayValue, ["base"])
        
        let hook2 = try object2.applyHook(
            for: #selector(getter: ExampleClass.arrayValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> [String]).self,
            hookSignature: (@convention(block) (NSObject) -> [String]).self
        ) { hook in
            return { `self` in
                return hook.original(self, hook.selector) + ["hook2"]
            }
        }
        XCTAssertEqual(object1.arrayValue, ["base", "hook1"])
        XCTAssertEqual(object2.arrayValue, ["base", "hook2"])
        
        XCTAssertNotEqual(
            NSStringFromClass(object_getClass(object1)),
            NSStringFromClass(object_getClass(object2))
        )
        
        try hook1.revert()
        XCTAssertEqual(object1.arrayValue, ["base"])
        XCTAssertEqual(object2.arrayValue, ["base", "hook2"])
        
        try hook2.revert()
        XCTAssertEqual(object1.arrayValue, ["base"])
        XCTAssertEqual(object2.arrayValue, ["base"])
    }
    
    // Hooking fails on an object that has KVO activated.
    func testKVO_observationBeforeHooking() throws {
        let object = ExampleClass()
        
        var didInvokeObserver = false
        let token = object.observe(\.intValue) { _, _ in
            didInvokeObserver = true
        }
        
        XCTAssertEqual(object.intValue, 1)
        XCTAssertEqual(didInvokeObserver, false)
        
        object.intValue = 2
        XCTAssertEqual(object.intValue, 2)
        XCTAssertEqual(didInvokeObserver, true)
        
        XCTAssertThrowsError(
            try object.applyHook(
                for: #selector(getter: ExampleClass.intValue),
                methodSignature: (@convention(c) (NSObject, Selector) -> Int).self,
                hookSignature: (@convention(block) (NSObject) -> Int).self
            ) { hook in
                return { `self` in
                    hook.original(self, hook.selector) + 1
                }
            },
            expected: InterposeError.kvoDetected(object)
        )
        XCTAssertEqual(object.intValue, 2)

        _ = token
    }
    
    // KVO works just fine on an object that has already been hooked.
    func testKVO_observationAfterHooking() throws {
        let object = ExampleClass()
        
        let hook = try object.applyHook(
            for: #selector(getter: ExampleClass.intValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> Int).self,
            hookSignature: (@convention(block) (NSObject) -> Int).self
        ) { hook in
            return { `self` in
                hook.original(self, hook.selector) + 1
            }
        }
        XCTAssertEqual(object.intValue, 2)
        
        try hook.revert()
        XCTAssertEqual(object.intValue, 1)
        
        try hook.apply()
        XCTAssertEqual(object.intValue, 2)
        
        var didInvokeObserver = false
        let token = object.observe(\.intValue) { _, _ in
            didInvokeObserver = true
        }
        
        XCTAssertEqual(object.intValue, 2)
        XCTAssertEqual(didInvokeObserver, false)
        
        object.intValue = 2
        XCTAssertEqual(object.intValue, 3)
        XCTAssertEqual(didInvokeObserver, true)
        
        _ = token
    }
    
    func testCleanUp_implementationPreserved() throws {
        let object = ExampleClass()
        var deallocated = false
        
        try autoreleasepool {
            let tracker = LifetimeTracker { deallocated = true }
            
            try object.applyHook(
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
        let object = ExampleClass()
        var deallocated = false
        
        try autoreleasepool {
            let tracker = LifetimeTracker { deallocated = true }
            
            let hook = try object.applyHook(
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
