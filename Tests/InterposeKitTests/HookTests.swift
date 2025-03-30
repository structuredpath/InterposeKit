@testable import InterposeKit
import XCTest

fileprivate class ExampleClass: NSObject {
    @objc dynamic var intValue: Int { 1 }
}

final class HookTests: XCTestCase {
    
    func testAccessingOriginalIMP() throws {
        typealias MethodSignature = @convention(c) (ExampleClass, Selector) -> Int
        typealias HookSignature = @convention(block) (ExampleClass) -> Int
        
        let object = ExampleClass()
        
        let hook = try Hook(
            target: .object(object),
            selector: #selector(getter: ExampleClass.intValue),
            build: { (hook: HookProxy<MethodSignature>) -> HookSignature in
                return { `self` in 2 }
            }
        )
        
        // Before applying the hook, originalIMP performs a dynamic lookup of the current method
        // implementation (which is still the unmodified original).
        do {
            let original = unsafeBitCast(
                hook.originalIMP,
                to: MethodSignature.self
            )
            
            XCTAssertEqual(original(object, #selector(getter: ExampleClass.intValue)), 1)
        }
        
        // After applying the hook, originalIMP returns the stored implementation that was
        // replaced. This avoids another dynamic lookup.
        do {
            try hook.apply()
            
            let original = unsafeBitCast(
                hook.originalIMP,
                to: MethodSignature.self
            )
            
            XCTAssertEqual(original(object, #selector(getter: ExampleClass.intValue)), 1)
        }
    }
    
}
