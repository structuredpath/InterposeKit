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
    
    func testRevertFailure_corrupted() throws {
        let hook = try Interpose.applyHook(
            on: ExampleClass.self,
            for: #selector(ExampleClass.foo),
            methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
            hookSignature: (@convention(block) (NSObject) -> Void).self
        ) { hook in
            return { `self` in }
        }
        XCTAssertEqual(hook.state, .active)
        
        // After applying the hook, we swizzle once more externally, putting the hook into a state,
        // in which it cannot restore the original implementation.
        let method = try XCTUnwrap(class_getInstanceMethod(
            ExampleClass.self,
            #selector(ExampleClass.foo)
        ))
        
        let externalBlock: @convention(block) (NSObject) -> Void = { _ in }
        let externalIMP = imp_implementationWithBlock(externalBlock)
        
        XCTAssertNotNil(class_replaceMethod(
            ExampleClass.self,
            #selector(ExampleClass.foo),
            externalIMP,
            method_getTypeEncoding(method)
        ))
        
        XCTAssertThrowsError(
            try hook.revert(),
            expected: InterposeError.revertCorrupted(
                class: ExampleClass.self,
                selector: #selector(ExampleClass.foo),
                imp: externalIMP
            )
        )
        XCTAssertEqual(hook.state, .failed)
    }
    
}
