//
//  SFTP.swift
//  Shout
//
//  Created by Vladislav Alexeev on 6/20/18.
//

import Foundation
import CSSH

public class SFTP {
    
    private class SFTPHandle {
        
        // Recommended buffer size accordingly to the docs:
        // https://www.libssh2.org/libssh2_sftp_write.html
        fileprivate static let bufferSize = 32768
        
        private let cSession: OpaquePointer
        private let sftpHandle: OpaquePointer
        private var buffer = [Int8](repeating: 0, count: SFTPHandle.bufferSize)
        
        init(cSession: OpaquePointer, sftpSession: OpaquePointer, remotePath: String, flags: Int32, mode: Int32) throws {
            guard let sftpHandle = libssh2_sftp_open_ex(
                sftpSession,
                remotePath,
                UInt32(remotePath.count),
                UInt(flags),
                Int(mode),
                LIBSSH2_SFTP_OPENFILE) else {
                    throw SSHError.mostRecentError(session: cSession, backupMessage: "libssh2_sftp_open_ex failed")
            }
            self.cSession = cSession
            self.sftpHandle = sftpHandle
        }
        
        func read() -> ReadWriteProcessor.ReadResult {
            let result = libssh2_sftp_read(sftpHandle, &buffer, SFTPHandle.bufferSize)
            return ReadWriteProcessor.processRead(result: result, buffer: &buffer, session: cSession)
        }
        
        func write(_ data: Data) -> ReadWriteProcessor.WriteResult {
            let result = data.withUnsafeBytes { (pointer: UnsafePointer<Int8>) -> Int in
                return libssh2_sftp_write(sftpHandle, pointer, data.count)
            }
            return ReadWriteProcessor.processWrite(result: result, session: cSession)
        }
        
        deinit {
            libssh2_sftp_close_handle(sftpHandle)
        }
        
    }
    
    private let cSession: OpaquePointer
    private let sftpSession: OpaquePointer
        
    public init(cSession: OpaquePointer) throws {
        guard let sftpSession = libssh2_sftp_init(cSession) else {
            throw SSHError.mostRecentError(session: cSession, backupMessage: "libssh2_sftp_init failed")
        }
        self.cSession = cSession
        self.sftpSession = sftpSession
    }
    
    deinit {
        libssh2_sftp_shutdown(sftpSession)
    }

    public func download(remotePath: String, localUrl: URL) throws {
        let sftpHandle = try SFTPHandle(
            cSession: cSession,
            sftpSession: sftpSession,
            remotePath: remotePath,
            flags: LIBSSH2_FXF_READ,
            mode: 0
        )
        
        FileManager.default.createFile(atPath: localUrl.path, contents: nil, attributes: nil)
        let fileHandle = try FileHandle(forWritingTo: localUrl)
        defer { fileHandle.closeFile() }

        var dataLeft = true
        while dataLeft {
            switch sftpHandle.read() {
            case .data(let data):
                fileHandle.write(data)
            case .done:
                dataLeft = false
            case .eagain:
                break
            case .error(let error):
                throw error
            }
        }
    }
    
    public func upload(localUrl: URL, remotePath: String, permissions: FilePermissions = .default) throws {
        let sftpHandle = try SFTPHandle(
            cSession: cSession,
            sftpSession: sftpSession,
            remotePath: remotePath,
            flags: LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT,
            mode: LIBSSH2_SFTP_S_IFREG | permissions.rawValue
        )
        
        let data = try Data(contentsOf: localUrl, options: .alwaysMapped)
        
        var offset = 0
        while offset < data.count {
            let upTo = Swift.min(offset + SFTPHandle.bufferSize, data.count)
            let subdata = data.subdata(in: offset ..< upTo)
            if subdata.count > 0 {
                switch sftpHandle.write(subdata) {
                case .written(let bytesSent):
                    offset += bytesSent
                case .eagain:
                    break
                case .error(let error):
                    throw error
                }
            }
        }
    }
}
