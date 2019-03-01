//
//  SCPChannel.swift
//  Shout
//
//  Created by Brandon Evans on 1/19/19.
//

import Foundation
import CSSH

public class SCPChannel {

    private let cSession: OpaquePointer
    private let cChannel: OpaquePointer
    private let localURL: URL
    private let remotePath: String

    public init(cSession: OpaquePointer, localURL: URL, remotePath: String, permissions: FilePermissions = .default) throws {
        guard
            let resources = try? localURL.resourceValues(forKeys: [.fileSizeKey]),
            let fileSize = resources.fileSize,
            let cChannel = libssh2_scp_send64(cSession, remotePath, permissions.rawValue, Int64(fileSize), 0, 0)
        else { throw LibSSH2Error(code: -1, session: cSession) }

        self.cSession = cSession
        self.cChannel = cChannel
        self.localURL = localURL
        self.remotePath = remotePath
    }

    public func sendFile() throws {
        guard let inputStream = InputStream(url: localURL) else { return }
        inputStream.open()
        defer { inputStream.close() }

        let bufferSize = 32768
        var buffer = Data(capacity: bufferSize)
        let streamID: Int32 = 0

        while inputStream.hasBytesAvailable {
            let bytesRead = buffer.withUnsafeMutableBytes { data in
                inputStream.read(data, maxLength: bufferSize)
            }
            if bytesRead == 0 { break }

            let bytesWritten = buffer.withUnsafeBytes { data in
                libssh2_channel_write_ex(cChannel, streamID, data, bytesRead)
            }
            try LibSSH2Error.checkOnRead(code: Int32(bytesWritten), session: cSession)
        }

        libssh2_channel_send_eof(cChannel)
        libssh2_channel_wait_eof(cChannel)
        libssh2_channel_close(cChannel)
        libssh2_channel_wait_closed(cChannel)
    }

    public func exitStatus() -> Int32 {
        return libssh2_channel_get_exit_status(cChannel)
    }

    deinit {
        libssh2_channel_free(cChannel)
    }

}
