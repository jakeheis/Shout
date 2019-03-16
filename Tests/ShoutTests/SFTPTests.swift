//
//  SFTPTests.swift
//  ShoutTests
//
//  Created by Jake Heiser on 3/15/19.
//

import Shout
import XCTest

class SFTPTests: XCTestCase {

    func testDownload() throws {
        try SSH.connect(host: ShoutServer.host, username: ShoutServer.username, authMethod: ShoutServer.authMethod) { (ssh) in
            let sftp = try ssh.openSftp()
            
            let destinationUrl = URL(fileURLWithPath: "/tmp/shout_hostname")
            
            if try destinationUrl.checkResourceIsReachable() == true {
                try FileManager.default.removeItem(at: destinationUrl)
            }
            
            XCTAssertFalse(FileManager.default.fileExists(atPath: destinationUrl.path))
            
            try sftp.download(remotePath: "/etc/hostname", localUrl: destinationUrl)
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: destinationUrl.path))
            XCTAssertTrue(try String(contentsOf: destinationUrl).count > 0)
            
            try FileManager.default.removeItem(at: destinationUrl)
        }
    }
    
    func testUpload() throws {
        try SSH.connect(host: ShoutServer.host, username: ShoutServer.username, authMethod: ShoutServer.authMethod) { (ssh) in
            let sftp = try ssh.openSftp()
            
            try sftp.upload(localUrl: URL(fileURLWithPath: String(#file)), remotePath: "/tmp/shout_upload_test.swift")
            
            let (status, contents) = try ssh.capture("cat /tmp/shout_upload_test.swift")
            XCTAssertEqual(status, 0)
            XCTAssertEqual(contents.components(separatedBy: "\n")[1], "//  SFTPTests.swift")
            
            XCTAssertEqual(try ssh.execute("rm /tmp/shout_upload_test.swift", silent: false), 0)
        }
    }

}
