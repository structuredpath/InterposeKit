@testable import InterposeKit
import XCTest

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
    
}
