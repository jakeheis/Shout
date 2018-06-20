//
//  SFTP.swift
//  Bindings
//
//  Created by Vladislav Alexeev on 6/20/18.
//

import Foundation
import CSSH

public class SFTP {
    private let sftpSession: OpaquePointer
    
    public struct Permissions : OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
        public static let read = Permissions(rawValue: 1 << 1)
        public static let write = Permissions(rawValue: 1 << 2)
        public static let execute = Permissions(rawValue: 1 << 3)
    }
    
    public struct FilePermissions {
        public var owner: Permissions
        public var group: Permissions
        public var others: Permissions

        public init(owner: Permissions, group: Permissions, others: Permissions) {
            self.owner = owner
            self.group = group
            self.others = others
        }
        
        public static func fromPosixPermissions(_ value: CShort) -> FilePermissions {
            var permissions = FilePermissions(owner: [], group: [], others: [])
            if (value & CShort(S_IRUSR) == CShort(S_IRUSR)) { permissions.owner.insert(.read) }
            if (value & CShort(S_IWUSR) == CShort(S_IWUSR)) { permissions.owner.insert(.write) }
            if (value & CShort(S_IXUSR) == CShort(S_IXUSR)) { permissions.owner.insert(.execute) }
            if (value & CShort(S_IRGRP) == CShort(S_IRGRP)) { permissions.group.insert(.read) }
            if (value & CShort(S_IWGRP) == CShort(S_IWGRP)) { permissions.group.insert(.write) }
            if (value & CShort(S_IXGRP) == CShort(S_IXGRP)) { permissions.group.insert(.execute) }
            if (value & CShort(S_IROTH) == CShort(S_IROTH)) { permissions.others.insert(.read) }
            if (value & CShort(S_IWOTH) == CShort(S_IWOTH)) { permissions.others.insert(.write) }
            if (value & CShort(S_IXOTH) == CShort(S_IXOTH)) { permissions.others.insert(.execute) }
            return permissions
        }
        
        public static let defaultPermissions = FilePermissions(owner: [.read, .write], group: [.read], others: [.read])
    }
    
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
            Int(LIBSSH2_SFTP_S_IFREG | libsshPermissionFlag(permissions)),
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
    
    private func libsshPermissionFlag(_ permissions: FilePermissions) -> Int32 {
        var flag: Int32 = 0
        if permissions.owner.contains(.read) { flag |= LIBSSH2_SFTP_S_IRUSR }
        if permissions.owner.contains(.write) { flag |= LIBSSH2_SFTP_S_IWUSR }
        if permissions.owner.contains(.execute) { flag |= LIBSSH2_SFTP_S_IXUSR }
        
        if permissions.group.contains(.read) { flag |= LIBSSH2_SFTP_S_IRGRP }
        if permissions.group.contains(.write) { flag |= LIBSSH2_SFTP_S_IWGRP }
        if permissions.group.contains(.execute) { flag |= LIBSSH2_SFTP_S_IXGRP }
        
        if permissions.others.contains(.read) { flag |= LIBSSH2_SFTP_S_IROTH }
        if permissions.others.contains(.write) { flag |= LIBSSH2_SFTP_S_IWOTH }
        if permissions.others.contains(.execute) { flag |= LIBSSH2_SFTP_S_IXOTH }
        
        return flag
    }
}
