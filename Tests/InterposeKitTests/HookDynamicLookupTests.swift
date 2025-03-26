@testable import InterposeKit
import XCTest
import Foundation

fileprivate class ExampleClass: NSObject {
    @objc dynamic func greet(name: String) -> String {
        return "Hello, \(name)!"
    }
}

class HookDynamicLookupTests: XCTestCase {
    func test() throws {
        typealias MethodSignature = @convention(c) (ExampleClass, Selector, String) -> String
        typealias HookSignature = @convention(block) (ExampleClass, String) -> String
        
        let obj = ExampleClass()
        
        // Create an ObjectHook for the 'greet(name:)' method.
        // Note: We don't explicitly set strategy.originalIMP, so the dynamic lookup path will be used.
        let hook = try Interpose.ObjectHook(
            object: obj,
            selector: #selector(ExampleClass.greet(name:)),
            build: { (hook: HookProxy<MethodSignature>) -> HookSignature in
                // Build a replacement block that calls the original implementation via the hook proxy.
                return { `self`, name in
                    return hook.original(self, hook.selector, name)
                }
            }
        )
        
        // Force the dynamic lookup path by ensuring no original IMP has been cached.
        // The following call will use `lookupOrigIMP` to find the method implementation.
        let original = unsafeBitCast(
            hook.originalIMP,
            to: (@convention(c) (ExampleClass, Selector, String) -> String).self
        )
        
        // Call the original implementation via the looked-up IMP.
        let result = original(obj, #selector(ExampleClass.greet(name:)), "World")
        XCTAssertEqual(result, "Hello, World!")
    }
}
