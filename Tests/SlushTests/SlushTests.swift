import XCTest
@testable import Slush

class SlushTests: XCTestCase {

    func testExample() {
        do {
            try SSH.connect(host: "jakeheis.com", username: "", authMethod: .agent) { (connection) in
                print(try connection.execute("ls -a"))
                print(try connection.execute("pwd"))
            }
        } catch let error {
            XCTFail(String(describing: error))
        }
    }

    static var allTests = [
        ("testExample", testExample),
    ]

}
