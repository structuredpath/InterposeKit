@testable import InterposeKit
import XCTest

fileprivate class ExampleClass: NSObject {
    @objc dynamic func foo() {}
}

fileprivate class ExampleSubclass: ExampleClass {}

final class HookTests: InterposeKitTestCase {
    
    func testStates_success() throws {
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
    
    func testStates_failure() throws {
        // Interpose on a subclass that inherits but does not implement `foo`.
        // We can prepare a hook, as the method is accessible from the subclass.
        let hook = try Interpose.prepareHook(
            on: ExampleSubclass.self,
            for: #selector(ExampleClass.foo),
            methodSignature: (@convention(c) (NSObject, Selector) -> Void).self,
            hookSignature: (@convention(block) (NSObject) -> Void).self
        ) { hook in
            return { `self` in }
        }
        XCTAssertEqual(hook.state, .pending)
        
        // But applying the hook fails because the subclass has no implementation.
        XCTAssertThrowsError(
            try hook.apply(),
            expected: InterposeError.implementationNotFound(
                class: ExampleSubclass.self,
                selector: #selector(ExampleClass.foo)
            )
        )
        XCTAssertEqual(hook.state, .failed)
    }
    
}
