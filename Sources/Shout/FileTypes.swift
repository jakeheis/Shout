//
//  File.swift
//  Shout
//
//  Created by Michal Duda on 09/21/2019.
//

import Foundation
import CSSH

public struct FileTypes: RawRepresentable {
    public let rawValue: Int32

    public var isLink: Bool {
        return rawValue & LIBSSH2_SFTP_S_IFMT == LIBSSH2_SFTP_S_IFLNK
    }

    public var isRegularFile: Bool {
        return rawValue & LIBSSH2_SFTP_S_IFMT == LIBSSH2_SFTP_S_IFREG
    }

    public var isDirectory: Bool {
        return rawValue & LIBSSH2_SFTP_S_IFMT == LIBSSH2_SFTP_S_IFDIR
    }

    public var isCharacterSpecialFile: Bool {
        return rawValue & LIBSSH2_SFTP_S_IFMT == LIBSSH2_SFTP_S_IFCHR
    }

    public var isBlockSpecialFile: Bool {
        return rawValue & LIBSSH2_SFTP_S_IFMT == LIBSSH2_SFTP_S_IFBLK
    }

    public var isFIFO: Bool {
        return rawValue & LIBSSH2_SFTP_S_IFMT == LIBSSH2_SFTP_S_IFIFO
    }

    public var isSocket: Bool {
        return rawValue & LIBSSH2_SFTP_S_IFMT == LIBSSH2_SFTP_S_IFSOCK
    }

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public init(attr: LIBSSH2_SFTP_ATTRIBUTES) {
        self.init(rawValue: Int32(attr.permissions))
    }
}

