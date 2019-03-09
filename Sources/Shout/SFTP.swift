//
//  SFTP.swift
//  Shout
//
//  Created by Vladislav Alexeev on 6/20/18.
//

import Foundation
import CSSH

public class SFTP {
    private let sftpSession: OpaquePointer
    
    // Recommended buffer size accordingly to the docs:
    // https://www.libssh2.org/libssh2_sftp_write.html
    private static let bufferSize = 32768
        
    public init(cSession: OpaquePointer) throws {
        guard let sftpSession = libssh2_sftp_init(cSession) else {
            throw LibSSH2Error(code: -1, message: "libssh2_sftp_init failed")
        }
        self.sftpSession = sftpSession
    }
    
    deinit {
        libssh2_sftp_shutdown(sftpSession)
    }

    public func download(remotePath: String, localUrl: URL) throws {
        guard let sftpHandle = libssh2_sftp_open_ex(
            sftpSession,
            remotePath,
            UInt32(remotePath.count),
            UInt(LIBSSH2_FXF_READ),
            0,
            LIBSSH2_SFTP_OPENFILE) else
        {
            throw LibSSH2Error(code: -1, message: "libssh2_sftp_open_ex failed")
        }

        defer { libssh2_sftp_close_handle(sftpHandle) }
        
        FileManager.default.createFile(atPath: localUrl.path, contents: nil, attributes: nil)
        let fileHandle = try FileHandle(forWritingTo: localUrl)
        defer { fileHandle.closeFile() }

        var buffer = Array<Int8>(repeating: 0, count: SFTP.bufferSize)

        var codeOrBytesReceived: Int
        repeat {
            codeOrBytesReceived = libssh2_sftp_read(sftpHandle, &buffer, SFTP.bufferSize)
            if codeOrBytesReceived < 0 && codeOrBytesReceived != Int(LIBSSH2_ERROR_EAGAIN) {
                throw LibSSH2Error(code: Int32(codeOrBytesReceived), message: "libssh2_sftp_read failed")
            }
            
            let data = Data(buffer: UnsafeBufferPointer(start: &buffer, count: codeOrBytesReceived))
            fileHandle.write(data)
        } while codeOrBytesReceived > 0
    }
    
    public func upload(localUrl: URL, remotePath: String, permissions: FilePermissions = .default) throws {
        guard let sftpHandle = libssh2_sftp_open_ex(
            sftpSession,
            remotePath,
            UInt32(remotePath.count),
            UInt(LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT),
            Int(LIBSSH2_SFTP_S_IFREG | permissions.rawValue),
            LIBSSH2_SFTP_OPENFILE) else
        {
            throw LibSSH2Error(code: -1, message: "libssh2_sftp_open_ex failed")
        }

        defer { libssh2_sftp_close_handle(sftpHandle) }
        
        let data = try Data(contentsOf: localUrl, options: .alwaysMapped)
        
        var offset = 0
        while offset < data.count {
            let upTo = Swift.min(offset + SFTP.bufferSize, data.count)
            let subdata = data.subdata(in: offset ..< upTo)
            if subdata.count > 0 {
                let bytesSent = try subdata.withUnsafeBytes { (pointer: UnsafePointer<Int8>) -> Int in
                    let codeOrBytesSent = libssh2_sftp_write(sftpHandle, pointer, subdata.count)
                    if codeOrBytesSent < 0 && codeOrBytesSent != Int(LIBSSH2_ERROR_EAGAIN) {
                        throw LibSSH2Error(code: Int32(codeOrBytesSent), message: "libssh2_sftp_write failed")
                    }
                    return codeOrBytesSent
                }
                offset += bytesSent
            }
        }
    }
}
