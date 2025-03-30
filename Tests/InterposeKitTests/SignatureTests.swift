import InterposeKit
import XCTest

fileprivate class ExampleClass: NSObject {
    
    @objc dynamic func passthroughInt(_ input: Int) -> Int { input }
    @objc dynamic func passthroughDouble(_ input: Double) -> Double { input }
    @objc dynamic func passthroughPoint(_ input: CGPoint) -> CGPoint { input }
    @objc dynamic func passthroughRect(_ input: CGRect) -> CGRect { input }
    @objc dynamic func passthroughTransform3D(_ input: CATransform3D) -> CATransform3D { input }
    @objc dynamic func passthroughString(_ input: String) -> String { input }
    @objc dynamic func passthroughObject(_ input: NSObject) -> NSObject { input }
    
    @objc dynamic func sum3(var1: Int, var2: Int, var3: Int) -> Int {
        var1 + var2 + var3
    }
    
    @objc dynamic func sum6(var1: Int, var2: Int, var3: Int, var4: Int, var5: Int, var6: Int) -> Int {
        var1 + var2 + var3 + var4 + var5 + var6
    }
    
}

final class SignatureTests: XCTestCase {
    
    override func setUpWithError() throws {
        Interpose.isLoggingEnabled = true
    }
    
    func testPassthroughInt() throws {
        let object = ExampleClass()
        
        let hook = try object.applyHook(
            for: #selector(ExampleClass.passthroughInt(_:)),
            methodSignature: (@convention(c) (NSObject, Selector, Int) -> Int).self,
            hookSignature: (@convention(block) (NSObject, Int) -> Int).self
        ) { hook in
            return { `self`, input in
                hook.original(self, hook.selector, input) + 1
            }
        }
        XCTAssertEqual(object.passthroughInt(42), 43)
        
        try hook.revert()
        XCTAssertEqual(object.passthroughInt(42), 42)
    }
    
    func testPassthroughDouble() throws {
        let object = ExampleClass()
        
        let hook = try object.applyHook(
            for: #selector(ExampleClass.passthroughDouble(_:)),
            methodSignature: (@convention(c) (NSObject, Selector, Double) -> Double).self,
            hookSignature: (@convention(block) (NSObject, Double) -> Double).self
        ) { hook in
            return { `self`, input in
                hook.original(self, hook.selector, input) + 0.5
            }
        }
        XCTAssertEqual(object.passthroughDouble(1.5), 2.0)
        
        try hook.revert()
        XCTAssertEqual(object.passthroughDouble(1.5), 1.5)
    }
    
    func testPassthroughPoint() throws {
        let object = ExampleClass()
        
        let hook = try object.applyHook(
            for: #selector(ExampleClass.passthroughPoint(_:)),
            methodSignature: (@convention(c) (NSObject, Selector, CGPoint) -> CGPoint).self,
            hookSignature: (@convention(block) (NSObject, CGPoint) -> CGPoint).self
        ) { hook in
            return { `self`, input in
                var point = hook.original(self, hook.selector, input)
                point.x += 1
                point.y += 1
                return point
            }
        }
        XCTAssertEqual(object.passthroughPoint(CGPoint(x: 1, y: 2)), CGPoint(x: 2, y: 3))
        
        try hook.revert()
        XCTAssertEqual(object.passthroughPoint(CGPoint(x: 1, y: 2)), CGPoint(x: 1, y: 2))
    }
    
    func testPassthroughRect() throws {
        let object = ExampleClass()
        
        let hook = try object.applyHook(
            for: #selector(ExampleClass.passthroughRect(_:)),
            methodSignature: (@convention(c) (NSObject, Selector, CGRect) -> CGRect).self,
            hookSignature: (@convention(block) (NSObject, CGRect) -> CGRect).self
        ) { hook in
            { `self`, rect in
                var rect = hook.original(self, hook.selector, rect)
                rect.origin.x += 1
                rect.size.width += 1
                return rect
            }
        }
        XCTAssertEqual(
            object.passthroughRect(CGRect(x: 1, y: 1, width: 10, height: 10)),
            CGRect(x: 2, y: 1, width: 11, height: 10)
        )
        
        try hook.revert()
        XCTAssertEqual(
            object.passthroughRect(CGRect(x: 1, y: 2, width: 10, height: 10)),
            CGRect(x: 1, y: 2, width: 10, height: 10)
        )
    }
    
    func testPassthroughTransform3D() throws {
        let object = ExampleClass()
        let input = CATransform3DMakeTranslation(1, 2, 3)
        
        let hook = try object.applyHook(
            for: #selector(ExampleClass.passthroughTransform3D(_:)),
            methodSignature: (@convention(c) (NSObject, Selector, CATransform3D) -> CATransform3D).self,
            hookSignature: (@convention(block) (NSObject, CATransform3D) -> CATransform3D).self
        ) { hook in
            { `self`, transform in
                var modified = hook.original(self, hook.selector, transform)
                modified.m44 += 1
                return modified
            }
        }
        
        var expected = input
        expected.m44 += 1
        XCTAssertTrue(CATransform3DEqualToTransform(object.passthroughTransform3D(input), expected))
        
        try hook.revert()
        XCTAssertTrue(CATransform3DEqualToTransform(object.passthroughTransform3D(input), input))
    }
    
    func testPassthroughString() throws {
        let object = ExampleClass()
        
        let hook = try object.applyHook(
            for: #selector(ExampleClass.passthroughString(_:)),
            methodSignature: (@convention(c) (NSObject, Selector, String) -> String).self,
            hookSignature: (@convention(block) (NSObject, String) -> String).self
        ) { hook in
            { `self`, input in hook.original(self, hook.selector, input) + "!" }
        }
        XCTAssertEqual(object.passthroughString("Test"), "Test!")
        
        try hook.revert()
        XCTAssertEqual(object.passthroughString("Test"), "Test")
    }
    
    func testPassthroughObject() throws {
        let object = ExampleClass()
        let input = NSObject()
        
        let hook = try object.applyHook(
            for: #selector(ExampleClass.passthroughObject(_:)),
            methodSignature: (@convention(c) (NSObject, Selector, NSObject) -> NSObject).self,
            hookSignature: (@convention(block) (NSObject, NSObject) -> NSObject).self
        ) { hook in
            { `self`, _ in NSObject() }
        }
        XCTAssertTrue(object.passthroughObject(input) !== input)
        
        try hook.revert()
        XCTAssertTrue(object.passthroughObject(input) === input)
    }
    
    func testSum3Ints() throws {
        let object = ExampleClass()
        
        let hook = try object.applyHook(
            for: #selector(ExampleClass.sum3(var1:var2:var3:)),
            methodSignature: (@convention(c) (NSObject, Selector, Int, Int, Int) -> Int).self,
            hookSignature: (@convention(block) (NSObject, Int, Int, Int) -> Int).self
        ) { hook in
            { `self`, var1, var2, var3 in
                hook.original(self, hook.selector, var1, var2, var3) + 1
            }
        }
        
        XCTAssertEqual(object.sum3(var1: 1, var2: 2, var3: 3), 7)
        
        try hook.revert()
        XCTAssertEqual(object.sum3(var1: 1, var2: 2, var3: 3), 6)
    }
    
    func testSum6Ints() throws {
        let object = ExampleClass()
        
        let hook = try object.applyHook(
            for: #selector(ExampleClass.sum6(var1:var2:var3:var4:var5:var6:)),
            methodSignature: (@convention(c) (NSObject, Selector, Int, Int, Int, Int, Int, Int) -> Int).self,
            hookSignature: (@convention(block) (NSObject, Int, Int, Int, Int, Int, Int) -> Int).self
        ) { hook in
            { `self`, var1, var2, var3, var4, var5, var6 in
                hook.original(self, hook.selector, var1, var2, var3, var4, var5, var6) + 1
            }
        }
        
        XCTAssertEqual(object.sum6(var1: 1, var2: 1, var3: 1, var4: 1, var5: 1, var6: 1), 7)
        
        try hook.revert()
        XCTAssertEqual(object.sum6(var1: 1, var2: 1, var3: 1, var4: 1, var5: 1, var6: 1), 6)
    }
    
}
