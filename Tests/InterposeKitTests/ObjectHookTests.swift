import InterposeKit
import XCTest

fileprivate class ExampleClass: NSObject {
    @objc dynamic var intValue = 1
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

}
