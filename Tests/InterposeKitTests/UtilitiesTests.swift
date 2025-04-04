@testable import InterposeKit
import XCTest

fileprivate class ExampleClass: NSObject {
    @objc dynamic var intValue: Int = 0
}

fileprivate class RealClass: NSObject {}
fileprivate class FakeClass: NSObject {}

extension NSObject {
    fileprivate var objcClass: AnyClass {
        self.perform(Selector((("class"))))?.takeUnretainedValue() as! AnyClass
    }
    
    fileprivate static var objcClass: AnyClass {
        self.perform(Selector((("class"))))?.takeUnretainedValue() as! AnyClass
    }
}

final class UtilitiesTests: XCTestCase {
    
    static let hasRunTestSetPerceivedClass = LockIsolated(false)
    
    func test_setPerceivedClass() throws {
        // Runs only once to avoid leaking class swizzling across test runs.
        try XCTSkipIf(Self.hasRunTestSetPerceivedClass.value, "Class override already applied.")
        Self.hasRunTestSetPerceivedClass.withValue{ $0 = true }
        
        let object = RealClass()
        
        XCTAssertTrue(object.objcClass === RealClass.self)
        XCTAssertTrue(object_getClass(object) === RealClass.self)
        
        XCTAssertTrue(RealClass.objcClass === RealClass.self)
        
        class_setPerceivedClass(for: RealClass.self, to: FakeClass.self)
        
        XCTAssertTrue(object.objcClass === FakeClass.self)
        XCTAssertTrue(object_getClass(object) === RealClass.self)
        
        XCTAssertTrue(RealClass.objcClass === FakeClass.self)
    }
    
    func test_isObjectKVOActive() {
        let object = ExampleClass()
        XCTAssertFalse(object_isKVOActive(object))
        
        var token1: NSKeyValueObservation? = object.observe(\.intValue) { _, _ in }
        XCTAssertTrue(object_isKVOActive(object))
        
        var token2: NSKeyValueObservation? = object.observe(\.intValue) { _, _ in }
        XCTAssertTrue(object_isKVOActive(object))
        
        _ = token1
        token1 = nil
        XCTAssertTrue(object_isKVOActive(object))
        
        _ = token2
        token2 = nil
        XCTAssertFalse(object_isKVOActive(object))
    }
    
    func test_impRemoveBlock() {
        var deallocated = false
        
        let imp: IMP = autoreleasepool {
            let tracker = LifetimeTracker { deallocated = true }
            
            let block: @convention(block) (NSObject) -> Void = { _ in
                tracker.keep()
            }
            
            return imp_implementationWithBlock(block)
        }
        
        // `imp` retains `block` which retains `tracker`.
        XCTAssertFalse(deallocated)
        
        // Detach `block` from `imp`, while keeping `imp`.
        imp_removeBlock(imp)
        
        // `block` and `tracker` should be deallocated now.
        XCTAssertTrue(deallocated)
    }
    
}
