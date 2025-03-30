@testable import InterposeKit
import XCTest

fileprivate class ExampleClass: NSObject {
    @objc dynamic func doSomething() {}
    @objc dynamic var intValue = 1
}

fileprivate class ExampleSubclass: ExampleClass {}

final class ClassHookTests: InterposeKitTestCase {
    
    func testLifecycle_applyHook() throws {
        let hook = try Interpose.applyHook(
            on: ExampleClass.self,
            for: #selector(getter: ExampleClass.intValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> Int).self,
            hookSignature: (@convention(block) (NSObject) -> Int).self
        ) { hook in
            return { `self` in
                1 + hook.original(self, hook.selector)
            }
        }
        
        XCTAssertEqual(ExampleClass().intValue, 2)
        XCTAssertEqual(hook.state, .active)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Active hook for -\[ExampleClass intValue\] \(originalIMP: 0x[0-9a-fA-F]+\)$"#
        )
        
        try hook.revert()
        
        XCTAssertEqual(ExampleClass().intValue, 1)
        XCTAssertEqual(hook.state, .pending)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Pending hook for -\[ExampleClass intValue\]$"#
        )
    }
    
    func testLifecycle_prepareHook() throws {
        let hook = try Interpose.prepareHook(
            on: ExampleClass.self,
            for: #selector(getter: ExampleClass.intValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> Int).self,
            hookSignature: (@convention(block) (NSObject) -> Int).self
        ) { hook in
            return { `self` in
                1 + hook.original(self, hook.selector)
            }
        }
        
        XCTAssertEqual(ExampleClass().intValue, 1)
        XCTAssertEqual(hook.state, .pending)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Pending hook for -\[ExampleClass intValue\]$"#
        )
        
        try hook.apply()
        
        XCTAssertEqual(ExampleClass().intValue, 2)
        XCTAssertEqual(hook.state, .active)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Active hook for -\[ExampleClass intValue\] \(originalIMP: 0x[0-9a-fA-F]+\)$"#
        )
        
        try hook.revert()
        
        XCTAssertEqual(ExampleClass().intValue, 1)
        XCTAssertEqual(hook.state, .pending)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Pending hook for -\[ExampleClass intValue\]$"#
        )
    }
    
    func testLifecycle_idempotentApplyAndRevert() throws {
        let object = ExampleClass()
        
        let hook = try Interpose.prepareHook(
            on: ExampleClass.self,
            for: #selector(getter: ExampleClass.intValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> Int).self,
            hookSignature: (@convention(block) (NSObject) -> Int).self
        ) { hook in
            return { `self` in
                1 + hook.original(self, hook.selector)
            }
        }
        
        XCTAssertEqual(object.intValue, 1)
        XCTAssertEqual(hook.state, .pending)
        
        try hook.apply()
        try hook.apply() // noop
        
        XCTAssertEqual(object.intValue, 2)
        XCTAssertEqual(hook.state, .active)
        
        try hook.revert()
        try hook.revert() // noop
        
        XCTAssertEqual(object.intValue, 1)
        XCTAssertEqual(hook.state, .pending)
        
        try hook.apply()
        
        XCTAssertEqual(object.intValue, 2)
        XCTAssertEqual(hook.state, .active)
        
        try hook.revert()
        
        XCTAssertEqual(object.intValue, 1)
        XCTAssertEqual(hook.state, .pending)
    }
    
    func testValidationFailure_methodNotFound() throws {
        XCTAssertThrowsError(
            try Interpose.prepareHook(
                on: ExampleClass.self,
                for: Selector(("doSomethingNotFound")),
                methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
                hookSignature: (@convention(block) (NSObject) -> Void).self
            ) { hook in
                return { `self` in }
            },
            expected: InterposeError.methodNotFound(
                class: ExampleClass.self,
                selector: Selector(("doSomethingNotFound"))
            )
        )
    }
    
    func testValidationFailure_methodNotDirectlyImplemented() throws {
        XCTAssertThrowsError(
            try Interpose.prepareHook(
                on: ExampleSubclass.self,
                for: #selector(ExampleClass.doSomething),
                methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
                hookSignature: (@convention(block) (NSObject) -> Void).self
            ) { hook in
                return { `self` in }
            },
            expected: InterposeError.methodNotDirectlyImplemented(
                class: ExampleSubclass.self,
                selector: #selector(ExampleClass.doSomething)
            )
        )
    }
    
    func testRevertFailure_corrupted() throws {
        let hook = try Interpose.applyHook(
            on: ExampleClass.self,
            for: #selector(ExampleClass.doSomething),
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
            #selector(ExampleClass.doSomething)
        ))
        
        let externalBlock: @convention(block) (NSObject) -> Void = { _ in }
        let externalIMP = imp_implementationWithBlock(externalBlock)
        
        XCTAssertNotNil(class_replaceMethod(
            ExampleClass.self,
            #selector(ExampleClass.doSomething),
            externalIMP,
            method_getTypeEncoding(method)
        ))
        
        XCTAssertThrowsError(
            try hook.revert(),
            expected: InterposeError.revertCorrupted(
                class: ExampleClass.self,
                selector: #selector(ExampleClass.doSomething),
                imp: externalIMP
            )
        )
        
        XCTAssertEqual(hook.state, .failed)
        XCTAssertMatchesRegex(
            hook.debugDescription,
            #"^Failed hook for -\[ExampleClass doSomething\]$"#
        )
    }
    
}
