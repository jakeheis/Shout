import XCTest
@testable import Slush

class SlushTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        _ = Session()
        XCTAssertEqual(Session.initResult, 0)
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
