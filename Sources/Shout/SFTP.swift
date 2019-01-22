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
    
    public init(cSession: OpaquePointer) throws {
        guard let sftpSession = libssh2_sftp_init(cSession) else {
            throw LibSSH2Error(code: -1, message: "libssh2_sftp_init failed")
        }
        self.sftpSession = sftpSession
    }
    
    deinit {
        libssh2_sftp_shutdown(sftpSession)
    }
    
    public func upload(localUrl: URL, remotePath: String, permissions: FilePermissions = FilePermissions.defaultPermissions) throws {
        guard let sftpHandle = libssh2_sftp_open_ex(
            sftpSession,
            remotePath,
            UInt32(remotePath.count),
            UInt(LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT),
            Int(LIBSSH2_SFTP_S_IFREG | FilePermissions.libsshPermissionFlag(permissions)),
            LIBSSH2_SFTP_OPENFILE) else
        {
            throw LibSSH2Error(code: -1, message: "libssh2_sftp_open_ex failed")
        }
        
        // Recommended buffer size accordingly to the docs:
        // https://www.libssh2.org/libssh2_sftp_write.html
        let bufferSize = 32768
        
        let data = try Data(contentsOf: localUrl, options: .alwaysMapped)
        
        var offset = 0
        while offset < data.count {
            let upTo = Swift.min(offset + bufferSize, data.count)
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
        libssh2_sftp_close_handle(sftpHandle)
    }
    
}
