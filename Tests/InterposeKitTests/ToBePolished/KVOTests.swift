@testable import InterposeKit
import Foundation
import XCTest

final class KVOTests: InterposeKitTestCase {

    // Helper observer that wraps a token and removes it on deinit.
    class TestClassObserver {
        var kvoToken: NSKeyValueObservation?
        var didCallObserver = false

        func observe(obj: TestClass) {
            kvoToken = obj.observe(\.age, options: .new) { [weak self] _, change in
                guard let age = change.newValue else { return }
                print("New age is: \(age)")
                self?.didCallObserver = true
            }
        }

        deinit {
            kvoToken?.invalidate()
        }
    }

    func testBasicKVO() throws {
        let testObj = TestClass()

        // KVO before hooking works, but hooking will fail
        try withExtendedLifetime(TestClassObserver()) { observer in
            observer.observe(obj: testObj)
            XCTAssertEqual(testObj.age, 1)
            testObj.age = 2
            XCTAssertEqual(testObj.age, 2)
            // Hooking is expected to fail
            XCTAssertThrowsError(
                try Interpose(testObj).prepareHook(
                    for: #selector(getter: TestClass.age),
                    methodSignature: (@convention(c) (NSObject, Selector) -> Int).self,
                    hookSignature: (@convention(block) (NSObject) -> Int).self
                ) { _ in
                    return { _ in 3 }
                },
                expected: InterposeError.keyValueObservationDetected(testObj)
            )
            XCTAssertEqual(testObj.age, 2)
        }

        // Hook without KVO!
        let hook = try testObj.applyHook(
            for: #selector(getter: TestClass.age),
            methodSignature: (@convention(c) (NSObject, Selector) -> Int).self,
            hookSignature: (@convention(block) (NSObject) -> Int).self
        ) { _ in
            return { _ in 3 }
        }
        XCTAssertEqual(testObj.age, 3)
        try hook.revert()
        XCTAssertEqual(testObj.age, 2)
        try hook.apply()
        XCTAssertEqual(testObj.age, 3)

        // Now we KVO after hooking!
        withExtendedLifetime(TestClassObserver()) { observer in
            observer.observe(obj: testObj)
            XCTAssertEqual(testObj.age, 3)
            // Setter is fine but won't change outcome
            XCTAssertFalse(observer.didCallObserver)
            testObj.age = 4
            XCTAssertTrue(observer.didCallObserver)
            XCTAssertEqual(testObj.age, 3)
        }
    }
}
