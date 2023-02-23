//
// SSHTests.swift
// ShoutTests
//
//  Created by Jake Heiser on 3/4/18.
//

import Shout
import XCTest

struct ShoutServer {
    static let host = ""
    static let username = ""
    static let password = ""
    static let agentAuth = SSHAgent()
    static let passwordAuth = SSHPassword(password)
    
    static let authMethod = agentAuth
}

class ShoutTests: XCTestCase {
    
    func testCapture() throws {
        let ssh = try SSH(host: ShoutServer.host)
        try ssh.authenticate(username: ShoutServer.username, authMethod: ShoutServer.authMethod)
        
        let (result, contents) = try ssh.capture("ls /")
        XCTAssertEqual(result, 0)
        XCTAssertTrue(contents.contains("bin"))
    }

    func testConnect() throws {
        try SSH.connect(host: ShoutServer.host, username: ShoutServer.username, authMethod: ShoutServer.authMethod) { (ssh) in
            let (result, contents) = try ssh.capture("ls /")
            XCTAssertEqual(result, 0)
            XCTAssertTrue(contents.contains("bin"))
        }
    }

    func testSendFile() throws {
        try SSH.connect(host: ShoutServer.host, username: ShoutServer.username, authMethod: ShoutServer.authMethod) { (ssh) in
            try ssh.sendFile(localURL: URL(fileURLWithPath: String(#file)), remotePath: "/tmp/shout_upload_test.swift")
            
            let (status, contents) = try ssh.capture("cat /tmp/shout_upload_test.swift")
            XCTAssertEqual(status, 0)
            XCTAssertEqual(contents.components(separatedBy: "\n")[1], "// SSHTests.swift")
            
            XCTAssertEqual(try ssh.execute("rm /tmp/shout_upload_test.swift", silent: false), 0)
        }
    }

    func testUnicode() throws {
        try SSH.connect(host: ShoutServer.host, username: ShoutServer.username, authMethod: ShoutServer.authMethod) { (ssh) in
            let (status, _) = try ssh.capture("touch /tmp/你好")
            XCTAssertEqual(status, 0)

            XCTAssertEqual(try ssh.execute("rm /tmp/你好", silent: false), 0)
        }
    }

}
