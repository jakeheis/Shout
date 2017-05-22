import XCTest
@testable import Slush

class SlushTests: XCTestCase {

    func testExample() {
        do {
            let ssh = try SSH(host: "jakeheis.com")
            print(try ssh.execute("ls -a"))
            print(try ssh.execute("pwd"))
        } catch let error {
            XCTFail(String(describing: error))
        }
    }

    static var allTests = [
        ("testExample", testExample),
    ]

}
