//
//  FilePermissions.swift
//  Shout
//
//  Created by Brandon Evans on 1/25/19.
//

import Foundation
import CSSH

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

    public static func libsshPermissionFlag(_ permissions: FilePermissions) -> Int32 {
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
