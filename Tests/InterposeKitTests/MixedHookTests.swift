import InterposeKit
import XCTest

fileprivate class ExampleClass: NSObject {
    @objc dynamic var arrayValue: [String] { ["base"] }
}

final class MixedHookTests: XCTestCase {
    
    override func setUpWithError() throws {
        Interpose.isLoggingEnabled = true
    }
    
    func test() throws {
        let object1 = ExampleClass()
        let object2 = ExampleClass()
        XCTAssertEqual(object1.arrayValue, ["base"])
        XCTAssertEqual(object2.arrayValue, ["base"])
        
        let classHook = try Interpose.applyHook(
            on: ExampleClass.self,
            for: #selector(getter: ExampleClass.arrayValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> [String]).self,
            hookSignature: (@convention(block) (NSObject) -> [String]).self
        ) { hook in
            return { `self` in
                return hook.original(self, hook.selector) + ["classHook"]
            }
        }
        XCTAssertEqual(object1.arrayValue, ["base", "classHook"])
        XCTAssertEqual(object2.arrayValue, ["base", "classHook"])
        
        let objectHook = try Interpose.applyHook(
            on: object1,
            for: #selector(getter: ExampleClass.arrayValue),
            methodSignature: (@convention(c) (NSObject, Selector) -> [String]).self,
            hookSignature: (@convention(block) (NSObject) -> [String]).self
        ) { hook in
            return { `self` in
                return hook.original(self, hook.selector) + ["objectHook"]
            }
        }
        XCTAssertEqual(object1.arrayValue, ["base", "classHook", "objectHook"])
        XCTAssertEqual(object2.arrayValue, ["base", "classHook"])
        
        try classHook.revert()
        XCTAssertEqual(object1.arrayValue, ["base", "objectHook"])
        XCTAssertEqual(object2.arrayValue, ["base"])
        
        try objectHook.revert()
        XCTAssertEqual(object1.arrayValue, ["base"])
        XCTAssertEqual(object2.arrayValue, ["base"])
    }
    
}
