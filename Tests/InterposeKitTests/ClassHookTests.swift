@testable import InterposeKit
import XCTest

fileprivate class ExampleClass: NSObject {
    @objc dynamic func foo() {}
}

fileprivate class ExampleSubclass: ExampleClass {}

final class ClassHookTests: InterposeKitTestCase {
    
    func testSuccess_applyHook() throws {
        let hook = try Interpose.applyHook(
            on: ExampleClass.self,
            for: #selector(ExampleClass.foo),
            methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
            hookSignature: (@convention(block) (NSObject) -> Void).self
        ) { hook in
            return { `self` in }
        }
        XCTAssertEqual(hook.state, .active)
        
        try hook.revert()
        XCTAssertEqual(hook.state, .pending)
    }
    
    func testSuccess_prepareHook() throws {
        let hook = try Interpose.prepareHook(
            on: ExampleClass.self,
            for: #selector(ExampleClass.foo),
            methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
            hookSignature: (@convention(block) (NSObject) -> Void).self
        ) { hook in
            return { `self` in }
        }
        XCTAssertEqual(hook.state, .pending)
        
        try hook.apply()
        XCTAssertEqual(hook.state, .active)
        
        try hook.revert()
        XCTAssertEqual(hook.state, .pending)
    }
    
    func testValidationFailure_methodNotFound() throws {
        XCTAssertThrowsError(
            try Interpose.prepareHook(
                on: ExampleClass.self,
                for: Selector(("bar")),
                methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
                hookSignature: (@convention(block) (NSObject) -> Void).self
            ) { hook in
                return { `self` in }
            },
            expected: InterposeError.methodNotFound(
                class: ExampleClass.self,
                selector: Selector(("bar"))
            )
        )
    }
    
    func testValidationFailure_methodNotDirectlyImplemented() throws {
        XCTAssertThrowsError(
            try Interpose.prepareHook(
                on: ExampleSubclass.self,
                for: #selector(ExampleClass.foo),
                methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
                hookSignature: (@convention(block) (NSObject) -> Void).self
            ) { hook in
                return { `self` in }
            },
            expected: InterposeError.methodNotDirectlyImplemented(
                class: ExampleSubclass.self,
                selector: #selector(ExampleClass.foo)
            )
        )
    }
    
}
