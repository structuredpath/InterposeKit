import XCTest

// https://medium.com/@hybridcattt/how-to-test-throwing-code-in-swift-c70a95535ee5
public func XCTAssertThrowsError<T, E: Error & Equatable>(
    _ expression: @autoclosure () throws -> T,
    expected expectedError: E,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertThrowsError(try expression(), message(), file: file, line: line) { error in
        if let error = error as? E {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } else {
            XCTFail(
                "The type of the thrown error \(type(of: error)) does not match the type of the expected one \(type(of: expectedError)).",
                file: file,
                line: line
            )
        }
    }
}
