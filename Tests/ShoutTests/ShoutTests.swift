//
// ShoutTests.swift
// Shout
//
//  Created by Jake Heiser on 3/4/18.
//

import XCTest
import Shout

class ShoutTests: XCTestCase {
    
    private static let testHost = "jakeheis.com"
    private static let username = ""
    private static let password = ""
    private static let agentAuth = SSHAgent()
    private static let passwordAuth = SSHPassword(password)
    
    // you can switch between auth methods here
    private let authMethod = agentAuth
    
    func testCapture() throws {
        let ssh = try SSH(host: ShoutTests.testHost)
        try ssh.authenticate(username: ShoutTests.username, privateKey: "")
        print(try ssh.capture("ls -a"))
        print(try ssh.capture("pwd"))
    }

    func testConnect() throws {
        try SSH.connect(host: ShoutTests.testHost, username: ShoutTests.username, authMethod: authMethod) { (ssh) in
            print(try ssh.capture("ls -a"))
            print(try ssh.capture("pwd"))
        }
    }
    
    func testUpload() throws {
        try SSH.connect(host: ShoutTests.testHost, username: ShoutTests.username, authMethod: authMethod) { (ssh) in
            let sftp = try ssh.openSftp()
            try sftp.upload(localUrl: URL(fileURLWithPath: String(#file)), remotePath: "/tmp/upload_test.swift")
            print(try ssh.capture("cat /tmp/upload_test.swift"))
            print(try ssh.capture("ls -l /tmp/upload_test.swift"))
            print(try ssh.capture("rm /tmp/upload_test.swift"))
        }
    }

    static var allTests = [
        ("testCapture", testCapture),
        ("testConnect", testConnect),
        ("testUpload", testUpload),
    ]

}
