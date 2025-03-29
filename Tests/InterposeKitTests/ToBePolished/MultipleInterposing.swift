import Foundation
import XCTest
@testable import InterposeKit

final class MultipleInterposingTests: InterposeKitTestCase {

    func testInterposeSingleObjectMultipleTimes() throws {
        let testObj = TestClass()
        let testObj2 = TestClass()

        XCTAssertEqual(testObj.sayHi(), testClassHi)
        XCTAssertEqual(testObj2.sayHi(), testClassHi)

        // Functions need to be `@objc dynamic` to be hookable.
        let interposer = try Interpose(testObj)
        let hook = try interposer.applyHook(
            for: #selector(TestClass.sayHi),
            methodSignature: (@convention(c) (NSObject, Selector) -> String).self,
            hookSignature: (@convention(block) (NSObject) -> String).self
        ) { store in
            { bSelf in
                return store.original(bSelf, store.selector) + testString
            }
        }

        XCTAssertEqual(testObj.sayHi(), testClassHi + testString)
        XCTAssertEqual(testObj2.sayHi(), testClassHi)

        try testObj.applyHook(
            for: #selector(TestClass.sayHi),
            methodSignature: (@convention(c) (NSObject, Selector) -> String).self,
            hookSignature: (@convention(block) (NSObject) -> String).self
        ) { hook in
            return { `self` in
                return hook.original(self, hook.selector) + testString2
            }
        }

        XCTAssertEqual(testObj.sayHi(), testClassHi + testString + testString2)
        try hook.revert()
        XCTAssertEqual(testObj.sayHi(), testClassHi + testString2)
    }

    func testInterposeAgeAndRevert() throws {
        let testObj = TestClass()
        XCTAssertEqual(testObj.age, 1)

        let interpose = try Interpose(testObj)
        let hook1 = try interpose.applyHook(
            for: #selector(getter: TestClass.age),
            methodSignature: (@convention(c) (NSObject, Selector) -> Int).self,
            hookSignature: (@convention(block) (NSObject) -> Int).self
        ) { _ in
            { _ in
                return 3
            }
        }
        
        XCTAssertEqual(testObj.age, 3)

        let hook2 = try interpose.applyHook(for: #selector(getter: TestClass.age),
                                       methodSignature: (@convention(c) (NSObject, Selector) -> Int).self,
                                       hookSignature: (@convention(block) (NSObject) -> Int).self) { _ in { _ in
            return 5
        }
        }
        
        XCTAssertEqual(testObj.age, 5)
        try hook2.revert()
        
        XCTAssertEqual(testObj.age, 3)
        try hook1.revert()
        
        XCTAssertEqual(testObj.age, 1)
    }
}
