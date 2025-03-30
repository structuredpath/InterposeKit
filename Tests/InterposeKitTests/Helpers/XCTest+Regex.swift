import XCTest

public func XCTAssertMatchesRegex(
    _ string: @autoclosure () -> String,
    _ pattern: String,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let stringValue = string()
    
    do {
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(stringValue.startIndex..<stringValue.endIndex, in: stringValue)
        let match = regex.firstMatch(in: stringValue, options: [], range: range)
        
        if match == nil {
            XCTFail(
                message().isEmpty
                ? "Expected string to match regex pattern:\nPattern: \(pattern)\nString: \(stringValue)"
                : message(),
                file: file,
                line: line
            )
        }
    } catch {
        XCTFail("Invalid regex pattern: \(pattern). Error: \(error)", file: file, line: line)
    }
}
