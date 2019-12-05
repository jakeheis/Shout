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
            
            try sftp.download(remotePath: "/etc/hostname", localURL: destinationUrl)
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: destinationUrl.path))
            XCTAssertTrue(try String(contentsOf: destinationUrl).count > 0)
            
            try FileManager.default.removeItem(at: destinationUrl)
        }
    }
    
    func testUpload() throws {
        try SSH.connect(host: ShoutServer.host, username: ShoutServer.username, authMethod: ShoutServer.authMethod) { (ssh) in
            let sftp = try ssh.openSftp()
            
            try sftp.upload(localURL: URL(fileURLWithPath: String(#file)), remotePath: "/tmp/shout_upload_test.swift")
            
            let (status, contents) = try ssh.capture("cat /tmp/shout_upload_test.swift")
            XCTAssertEqual(status, 0)
            XCTAssertEqual(contents.components(separatedBy: "\n")[1], "//  SFTPTests.swift")
            
            XCTAssertEqual(try ssh.execute("rm /tmp/shout_upload_test.swift", silent: false), 0)
        }
    }
    
    func testCreateDirectory() throws {
        try SSH.connect(host: ShoutServer.host, username: ShoutServer.username, authMethod: ShoutServer.authMethod) { (ssh) in
            let sftp = try ssh.openSftp()
            
            try sftp.createDirectory("/tmp/shout_folder_test")
            
            let (status, contents) = try ssh.capture("if test -d /tmp/shout_folder_test; then echo \"exists\"; fi")
            XCTAssertEqual(status, 0)
            XCTAssertEqual(contents.components(separatedBy: "\n")[0], "exists")
            
            XCTAssertEqual(try ssh.execute("rm -rf /tmp/shout_folder_test", silent: false), 0)
        }
    }
    
    func testRemoveDirectory() throws {
        try SSH.connect(host: ShoutServer.host, username: ShoutServer.username, authMethod: ShoutServer.authMethod) { (ssh) in
            let sftp = try ssh.openSftp()
            
            // First create directory
            try sftp.createDirectory("/tmp/shout_folder_test")
            let (statusC, contentsC) = try ssh.capture("if test -d /tmp/shout_folder_test; then echo \"exists\"; fi")
            XCTAssertEqual(statusC, 0)
            XCTAssertEqual(contentsC.components(separatedBy: "\n")[0], "exists")
            
            // Then delete
            try sftp.removeDirectory("/tmp/shout_folder_test")
            
            let (statusR, contentsR) = try ssh.capture("if test ! -d /tmp/shout_remove_test; then echo \"removed\"; fi")
            XCTAssertEqual(statusR, 0)
            XCTAssertEqual(contentsR.components(separatedBy: "\n")[0], "removed")
        }
    }
    
    func testRename() throws {
        try SSH.connect(host: ShoutServer.host, username: ShoutServer.username, authMethod: ShoutServer.authMethod) { (ssh) in
            let sftp = try ssh.openSftp()
            
            // Create dummy file
            let (statusC, _) = try ssh.capture("touch /tmp/shout_rename_test1")
            XCTAssertEqual(statusC, 0)
            
            // Then rename
            try sftp.rename(src: "/tmp/shout_rename_test1", dest: "/tmp/shout_rename_test2", override: true)
            
            // Check if old file is gone
            let (statusO, contentsO) = try ssh.capture("if test ! -f /tmp/shout_remove_test; then echo \"gone\"; fi")
            XCTAssertEqual(statusO, 0)
            XCTAssertEqual(contentsO.components(separatedBy: "\n")[0], "gone")
            
            // Check if new file is there
            let (statusN, contentsN) = try ssh.capture("if test -f /tmp/shout_rename_test2; then echo \"exists\"; fi")
            XCTAssertEqual(statusN, 0)
            XCTAssertEqual(contentsN.components(separatedBy: "\n")[0], "exists")
            
            XCTAssertEqual(try ssh.execute("rm /tmp/shout_rename_test2", silent: false), 0)
        }
    }
    
    func testRemove() throws {
        try SSH.connect(host: ShoutServer.host, username: ShoutServer.username, authMethod: ShoutServer.authMethod) { (ssh) in
            let sftp = try ssh.openSftp()
            
            // Create dummy file
            let (statusC, _) = try ssh.capture("touch /tmp/shout_remove_test")
            XCTAssertEqual(statusC, 0)
            
            // Remove file
            try sftp.removeFile("/tmp/shout_remove_test")
            
            // Check if old file is gone
            let (statusR, contentsR) = try ssh.capture("if test ! -f /tmp/shout_remove_test; then echo \"removed\"; fi")
            XCTAssertEqual(statusR, 0)
            XCTAssertEqual(contentsR.components(separatedBy: "\n")[0], "removed")
        }
    }

}
