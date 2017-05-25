import XCTest
@testable import Slush

class SlushTests: XCTestCase {

    func testExample() {
        sleep(1)
        do {
            try SSH.connect(host: "jakeheis.com", username: "", authMethod: .agent) { (connection) in
                print(try connection.capture("ls -a"))
                print(try connection.capture("pwd"))
            }
        } catch let error {
            XCTFail(String(describing: error))
        }
    }

    static var allTests = [
        ("testExample", testExample),
    ]

}
