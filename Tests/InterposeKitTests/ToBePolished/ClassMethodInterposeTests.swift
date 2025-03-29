@testable import InterposeKit
import XCTest

final class ClassMethodInterposeTests: InterposeKitTestCase {
    
    func testClassMethod() {
        XCTAssertThrowsError(
            try Interpose.prepareHook(
                on: TestClass.self,
                for: #selector(getter: TestClass.staticInt),
                methodSignature: (@convention(c) (NSObject, Selector) -> Int).self,
                hookSignature: (@convention(block) (NSObject) -> Int).self
            ) { hook in
                return { _ in 73 }
            },
            expected: InterposeError.methodNotFound(TestClass.self, #selector(getter: TestClass.staticInt))
        )
    }
    
}
