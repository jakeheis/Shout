import XCTest
@testable import SSH

class SlushTests: XCTestCase {

    func testExample() {
        sleep(1)
        do {
            try SSH.connect(host: "jakeheis.com", username: "", authMethod: SSH.Agent()) { (connection) in
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
