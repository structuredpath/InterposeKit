@testable import InterposeKit
import XCTest

final class ClassMethodInterposeTests: InterposeKitTestCase {
    
    func testClassMethod() {
        XCTAssertThrowsError(
            try Interpose(TestClass.self) {
                try $0.prepareHook(
                    #selector(getter: TestClass.staticInt),
                    methodSignature: (@convention(c) (AnyObject, Selector) -> Int).self,
                    hookSignature: (@convention(block) (AnyObject) -> Int).self
                ) { hook in
                    return { _ in 73 }
                }
            }
        ) { error in
            let typedError = error as! InterposeError
            XCTAssertEqual(typedError, .methodNotFound(TestClass.self, #selector(getter: TestClass.staticInt)))
        }
    }
    
}
