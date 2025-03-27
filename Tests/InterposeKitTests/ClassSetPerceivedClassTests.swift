@testable import InterposeKit
import XCTest

fileprivate class RealClass: NSObject {}
fileprivate class FakeClass: NSObject {}

final class ClassSetPerceivedClassTests: XCTestCase {
    
    func test() {
        let object = RealClass()
        
        XCTAssertTrue(object.perform(Selector((("class"))))?.takeUnretainedValue() === RealClass.self)
        XCTAssertTrue(object_getClass(object) === RealClass.self)
        
        XCTAssertTrue(RealClass.perform(Selector((("class"))))?.takeUnretainedValue() === RealClass.self)
        
        class_setPerceivedClass(for: RealClass.self, to: FakeClass.self)
        
        XCTAssertTrue(object.perform(Selector((("class"))))?.takeUnretainedValue() === FakeClass.self)
        XCTAssertTrue(object_getClass(object) === RealClass.self)
        
        XCTAssertTrue(RealClass.perform(Selector((("class"))))?.takeUnretainedValue() === FakeClass.self)
    }
    
}
