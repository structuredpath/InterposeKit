import XCTest
@testable import InterposeKit

final class InterposeKitTests: InterposeKitTestCase {

    override func setUpWithError() throws {
        Interpose.isLoggingEnabled = true
    }

    func testClassOverrideAndRevert() throws {
        let testObj = TestClass()
        XCTAssertEqual(testObj.sayHi(), testClassHi)

        // Functions need to be `@objc dynamic` to be hookable.
        let hook = try Interpose.applyHook(
            on: TestClass.self,
            for: #selector(TestClass.sayHi),
            methodSignature: (@convention(c) (NSObject, Selector) -> String).self,
            hookSignature: (@convention(block) (NSObject) -> String).self) { store in { bSelf in
                // You're free to skip calling the original implementation.
                print("Before Interposing \(bSelf)")
                let string = store.original(bSelf, store.selector)
                print("After Interposing \(bSelf)")
                
                return string + testString
            }
            }
        print(TestClass().sayHi())

        // Test various apply/revert's
        XCTAssertEqual(testObj.sayHi(), testClassHi + testString)
        try hook.revert()
        XCTAssertEqual(testObj.sayHi(), testClassHi)
        try hook.apply()
        XCTAssertEqual(testObj.sayHi(), testClassHi + testString)
        try hook.apply() // noop
        try hook.apply() // noop
        try hook.revert()
        try hook.revert() // noop
        try hook.apply()
        try hook.revert()
        XCTAssertEqual(testObj.sayHi(), testClassHi)
    }

    func testSubclassOverride() throws {
        let testObj = TestSubclass()
        XCTAssertEqual(testObj.sayHi(), testClassHi + testSubclass)

        // Swizzle test class
        let hook = try Interpose.applyHook(
            on: TestClass.self,
            for: #selector(TestClass.sayHi),
            methodSignature: (@convention(c) (NSObject, Selector) -> String).self,
            hookSignature: (@convention(block) (NSObject) -> String).self) { store in { bSelf in
                return store.original(bSelf, store.selector) + testString
            }
            }

        XCTAssertEqual(testObj.sayHi(), testClassHi + testString + testSubclass)
        try hook.revert()
        XCTAssertEqual(testObj.sayHi(), testClassHi + testSubclass)
        try hook.apply()
        XCTAssertEqual(testObj.sayHi(), testClassHi + testString + testSubclass)

        // Swizzle subclass, automatically applys
        let interposedSubclass = try Interpose.applyHook(
            on: TestSubclass.self,
            for: #selector(TestSubclass.sayHi),
            methodSignature: (@convention(c) (NSObject, Selector) -> String).self,
            hookSignature: (@convention(block) (NSObject) -> String).self) { store in { bSelf in
                return store.original(bSelf, store.selector) + testString
                }
        }

        XCTAssertEqual(testObj.sayHi(), testClassHi + testString + testSubclass + testString)
        try hook.revert()
        XCTAssertEqual(testObj.sayHi(), testClassHi + testSubclass + testString)
        try interposedSubclass.revert()
        XCTAssertEqual(testObj.sayHi(), testClassHi + testSubclass)
    }

    func testInterposedCleanup() throws {
        var deallocated = false

        try autoreleasepool {
            let tracker = LifetimeTracker {
                deallocated = true
            }

            // Swizzle test class
            let interposer = try Interpose.applyHook(
                on: TestClass.self,
                for: #selector(TestClass.doNothing),
                methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
                hookSignature: (@convention(block) (NSObject) -> Void).self) { store in { bSelf in
                    tracker.keep()
                    return store.original(bSelf, store.selector)
                    }
            }

            // Dealloc interposer without removing hooks
            _ = interposer
        }

        // Unreverted block should not be deallocated
        XCTAssertFalse(deallocated)
    }

    func testRevertedCleanup_class() throws {
        var deallocated = false

        try autoreleasepool {
            let tracker = LifetimeTracker {
                deallocated = true
            }

            // Swizzle test class
            let hook = try Interpose.applyHook(
                on: TestClass.self,
                for: #selector(TestClass.doNothing),
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

        // Verify that the block was deallocated
        XCTAssertTrue(deallocated)
    }
    
    func testRevertedCleanup_object() throws {
        var deallocated = false
        
        try autoreleasepool {
            let tracker = LifetimeTracker {
                deallocated = true
            }
            
            let object = TestClass()
            let hook = try Interpose.applyHook(
                on: object,
                for: #selector(TestClass.doNothing),
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
        
        // Verify that the block was deallocated
        XCTAssertTrue(deallocated)
    }

    func testImpRemoveBlockWorks() {
        var deallocated = false

        let imp: IMP = autoreleasepool {
            let tracker = LifetimeTracker {
                deallocated = true
            }

            let block: @convention(block) (NSObject) -> Void = { _ in
                // retain `tracker` inside a block
                tracker.keep()
            }

            return imp_implementationWithBlock(block)
        }

        // `imp` retains `block` which retains `tracker`
        XCTAssertFalse(deallocated)

        // Detach `block` from `imp`
        imp_removeBlock(imp)

        // `block` and `tracker` should be deallocated now
        XCTAssertTrue(deallocated)
    }

    class LifetimeTracker {
        let deinitCalled: () -> Void

        init(deinitCalled: @escaping () -> Void) {
            self.deinitCalled = deinitCalled
        }

        deinit {
            deinitCalled()
        }

        func keep() { }
    }
    
}
