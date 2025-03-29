@testable import InterposeKit
import XCTest

final class ClassMethodInterposeTests: InterposeKitTestCase {
    
    func testClassMethod() {
        let interposer = Interpose(TestClass.self)
        
        XCTAssertThrowsError(
            try interposer.prepareHook(
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
