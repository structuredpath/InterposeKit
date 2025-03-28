import Foundation
import XCTest
@testable import InterposeKit

final class ObjectInterposeTests: InterposeKitTestCase {

    func testInterposeSingleObject() throws {
        let testObj = TestClass()
        let testObj2 = TestClass()

        XCTAssertEqual(testObj.sayHi(), testClassHi)
        XCTAssertEqual(testObj2.sayHi(), testClassHi)

        let hook = try testObj.applyHook(
            for: #selector(TestClass.sayHi),
            methodSignature: (@convention(c) (AnyObject, Selector) -> String).self,
            hookSignature: (@convention(block) (AnyObject) -> String).self
        ) { hook in
            return { `self` in
                print("Before Interposing \(self)")
                let string = hook.original(self, hook.selector)
                print("After Interposing \(self)")
                return string + testString
            }
        }

        XCTAssertEqual(testObj.sayHi(), testClassHi + testString)
        XCTAssertEqual(testObj2.sayHi(), testClassHi)
        try hook.revert()
        XCTAssertEqual(testObj.sayHi(), testClassHi)
        XCTAssertEqual(testObj2.sayHi(), testClassHi)
        try hook.apply()
        XCTAssertEqual(testObj.sayHi(), testClassHi + testString)
        XCTAssertEqual(testObj2.sayHi(), testClassHi)
    }

    func testInterposeSingleObjectInt() throws {
        let testObj = TestClass()
        let returnIntDefault = testObj.returnInt()
        let returnIntOverrideOffset = 2
        XCTAssertEqual(testObj.returnInt(), returnIntDefault)

        let hook = try testObj.applyHook(
            for: #selector(TestClass.returnInt),
            methodSignature: (@convention(c) (AnyObject, Selector) -> Int).self,
            hookSignature: (@convention(block) (AnyObject) -> Int).self
        ) { hook in
            return { `self` in
                let int = hook.original(self, hook.selector)
                return int + returnIntOverrideOffset
            }
        }

        XCTAssertEqual(testObj.returnInt(), returnIntDefault + returnIntOverrideOffset)
        try hook.revert()
        XCTAssertEqual(testObj.returnInt(), returnIntDefault)
        try hook.apply()
        // ensure we really don't leak into another object
        let testObj2 = TestClass()
        XCTAssertEqual(testObj2.returnInt(), returnIntDefault)
        XCTAssertEqual(testObj.returnInt(), returnIntDefault + returnIntOverrideOffset)
        try hook.revert()
        XCTAssertEqual(testObj.returnInt(), returnIntDefault)
    }

    func testDoubleIntegerInterpose() throws {
        let testObj = TestClass()
        let returnIntDefault = testObj.returnInt()
        let returnIntOverrideOffset = 2
        let returnIntClassMultiplier = 4
        XCTAssertEqual(testObj.returnInt(), returnIntDefault)

        // Functions need to be `@objc dynamic` to be hookable.
        let hook = try testObj.applyHook(
            for: #selector(TestClass.returnInt),
            methodSignature: (@convention(c) (AnyObject, Selector) -> Int).self,
            hookSignature: (@convention(block) (AnyObject) -> Int).self
        ) { hook in
            return { `self` in
                // You're free to skip calling the original implementation.
                hook.original(self, hook.selector) + returnIntOverrideOffset
            }
        }
        XCTAssertEqual(testObj.returnInt(), returnIntDefault + returnIntOverrideOffset)

        // Interpose on TestClass itself!
        let classInterposer = Interpose(TestClass.self)
        let classHook = try classInterposer.applyHook(
            for: #selector(TestClass.returnInt),
            methodSignature: (@convention(c) (AnyObject, Selector) -> Int).self,
            hookSignature: (@convention(block) (AnyObject) -> Int).self
        ) { hook in
            return {
                hook.original($0, hook.selector) * returnIntClassMultiplier
            }
        }

        XCTAssertEqual(testObj.returnInt(), (returnIntDefault * returnIntClassMultiplier) + returnIntOverrideOffset)

        // ensure we really don't leak into another object
        let testObj2 = TestClass()
        XCTAssertEqual(testObj2.returnInt(), returnIntDefault * returnIntClassMultiplier)

        try hook.revert()
        XCTAssertEqual(testObj.returnInt(), returnIntDefault * returnIntClassMultiplier)
        try classHook.revert()
        XCTAssertEqual(testObj.returnInt(), returnIntDefault)
    }

    func test3IntParameters() throws {
        let testObj = TestClass()
        XCTAssertEqual(testObj.calculate(var1: 1, var2: 2, var3: 3), 1 + 2 + 3)

        // Functions need to be `@objc dynamic` to be hookable.
        let hook = try testObj.applyHook(
            for: #selector(TestClass.calculate),
            methodSignature: (@convention(c) (AnyObject, Selector, Int, Int, Int) -> Int).self,
            hookSignature: (@convention(block) (AnyObject, Int, Int, Int) -> Int).self
        ) { hook in
            return {
                let orig = hook.original($0, hook.selector, $1, $2, $3)
                return orig + 1
            }
        }
        XCTAssertEqual(testObj.calculate(var1: 1, var2: 2, var3: 3), 1 + 2 + 3 + 1)
        try hook.revert()
    }

    func test6IntParameters() throws {
        let testObj = TestClass()

        XCTAssertEqual(testObj.calculate2(var1: 1, var2: 2, var3: 3,
                                          var4: 4, var5: 5, var6: 6), 1 + 2 + 3 + 4 + 5 + 6)

        // Functions need to be `@objc dynamic` to be hookable.
        let hook = try testObj.applyHook(
            for: #selector(TestClass.calculate2),
            methodSignature: (@convention(c) (AnyObject, Selector, Int, Int, Int, Int, Int, Int) -> Int).self,
            hookSignature: (@convention(block) (AnyObject, Int, Int, Int, Int, Int, Int) -> Int).self
        ) { hook in
            return {
                // You're free to skip calling the original implementation.
                let orig = hook.original($0, hook.selector, $1, $2, $3, $4, $5, $6)
                return orig + 1
            }
        }
        XCTAssertEqual(testObj.calculate2(var1: 1, var2: 2, var3: 3,
                                          var4: 4, var5: 5, var6: 6), 1 + 2 + 3 + 4 + 5 + 6 + 1)
        try hook.revert()
    }

    func testObjectCallReturn() throws {
        let testObj = TestClass()
        let str = "foo"
        XCTAssertEqual(testObj.doubleString(string: str), str + str)

        // Functions need to be `@objc dynamic` to be hookable.
        let hook = try testObj.applyHook(
            for: #selector(TestClass.doubleString),
            methodSignature: (@convention(c) (AnyObject, Selector, String) -> String).self,
            hookSignature: (@convention(block) (AnyObject, String) -> String).self
        ) { hook in
            return { `self`, parameter in
                hook.original(self, hook.selector, parameter) + str
            }
        }
        XCTAssertEqual(testObj.doubleString(string: str), str + str + str)
        try hook.revert()
        XCTAssertEqual(testObj.doubleString(string: str), str + str)
    }
    
    func testHook_getPoint() throws {
        let object = TestClass()
        XCTAssertEqual(object.getPoint(), CGPoint(x: -1, y: 1))
        
        let hook = try object.applyHook(
            for: #selector(TestClass.getPoint),
            methodSignature: (@convention(c) (NSObject, Selector) -> CGPoint).self,
            hookSignature: (@convention(block) (NSObject) -> CGPoint).self
        ) { hook in
            return { `self` in
                var point = hook.original(self, hook.selector)
                point.x += 2
                point.y += 2
                return point
            }
        }
        
        XCTAssertEqual(object.getPoint(), CGPoint(x: 1, y: 3))
        
        try hook.revert()
        XCTAssertEqual(object.getPoint(), CGPoint(x: -1, y: 1))
    }
    
    func testHook_passthroughPoint() throws {
        let object = TestClass()
        
        XCTAssertEqual(
            object.passthroughPoint(CGPoint(x: 1, y: 1)),
            CGPoint(x: 1, y: 1)
        )
        
        let hook = try object.applyHook(
            for: #selector(TestClass.passthroughPoint(_:)),
            methodSignature: (@convention(c) (NSObject, Selector, CGPoint) -> CGPoint).self,
            hookSignature: (@convention(block) (NSObject, CGPoint) -> CGPoint).self
        ) { hook in
            return { `self`, inPoint in
                var outPoint = hook.original(self, hook.selector, inPoint)
                outPoint.x += 1
                outPoint.y += 1
                return outPoint
            }
        }
        
        XCTAssertEqual(
            object.passthroughPoint(CGPoint(x: 1, y: 1)),
            CGPoint(x: 2, y: 2)
        )
        
        try hook.revert()
        
        XCTAssertEqual(
            object.passthroughPoint(CGPoint(x: 1, y: 1)),
            CGPoint(x: 1, y: 1)
        )
    }
    
//    func testLargeStructReturn() throws {
//        let testObj = TestClass()
//        let transform = CATransform3D()
//        XCTAssertEqual(testObj.invert3DTransform(transform), transform.inverted)
//
//        func transformMatrix(_ matrix: CATransform3D) -> CATransform3D {
//            matrix.translated(x: 10, y: 5, z: 2)
//        }
//
//        // Functions need to be `@objc dynamic` to be hookable.
//        let hook = try testObj.hook(#selector(TestClass.invert3DTransform)) { (store: TypedHook
//            <@convention(c)(AnyObject, Selector, CATransform3D) -> CATransform3D,
//            @convention(block) (AnyObject, CATransform3D) -> CATransform3D>) in {
//                let matrix = store.original($0, store.selector, $1)
//                return transformMatrix(matrix)
//            }
//        }
//        XCTAssertEqual(testObj.invert3DTransform(transform), transformMatrix(transform.inverted))
//        try hook.revert()
//        XCTAssertEqual(testObj.invert3DTransform(transform), transform.inverted)
//    }
}
