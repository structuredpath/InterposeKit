@testable import InterposeKit
import XCTest

fileprivate class ExampleClass: NSObject {
    @objc dynamic var value = 0
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
    
    func test_setPerceivedClass() {
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
        
        var token1: NSKeyValueObservation? = object.observe(\.value, options: []) { _, _ in }
        XCTAssertTrue(object_isKVOActive(object))
        
        var token2: NSKeyValueObservation? = object.observe(\.value, options: []) { _, _ in }
        XCTAssertTrue(object_isKVOActive(object))
        
        _ = token1
        token1 = nil
        XCTAssertTrue(object_isKVOActive(object))
        
        _ = token2
        token2 = nil
        XCTAssertFalse(object_isKVOActive(object))
    }
    
}
