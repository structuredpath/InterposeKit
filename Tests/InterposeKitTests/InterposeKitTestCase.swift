import XCTest
@testable import InterposeKit

class InterposeKitTestCase: XCTestCase {
    override func setUpWithError() throws {
        Interpose.isLoggingEnabled = true
    }
}
