//
//  SFTP.swift
//  Shout
//
//  Created by Vladislav Alexeev on 6/20/18.
//

import Foundation
import CSSH

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#else
import Glibc
#endif



/// Manages an SFTP session
public class SFTP {

    /// A threading lock based on `libpthread` instead of `libdispatch`.
///
/// This object provides a lock on top of a single `pthread_mutex_t`. This kind
/// of lock is safe to use with `libpthread`-based threading models, such as the
/// one used by NIO.
    internal final class Lock {
        fileprivate let mutex: UnsafeMutablePointer<pthread_mutex_t> = UnsafeMutablePointer.allocate(capacity: 1)

        /// Create a new lock.
        public init() {
            let err = pthread_mutex_init(self.mutex, nil)
            precondition(err == 0)
        }

        deinit {
            let err = pthread_mutex_destroy(self.mutex)
            precondition(err == 0)
            self.mutex.deallocate()
        }

        /// Acquire the lock.
        ///
        /// Whenever possible, consider using `withLock` instead of this method and
        /// `unlock`, to simplify lock handling.
        public func lock() {
            let err = pthread_mutex_lock(self.mutex)
            precondition(err == 0)
        }

        /// Release the lock.
        ///
        /// Whenever possible, consider using `withLock` instead of this method and
        /// `lock`, to simplify lock handling.
        public func unlock() {
            let err = pthread_mutex_unlock(self.mutex)
            precondition(err == 0)
        }
    }

    /// Direct bindings to libssh2_sftp
    private class SFTPHandle {
        
        // Recommended buffer size accordingly to the docs:
        // https://www.libssh2.org/libssh2_sftp_write.html
        fileprivate static let bufferSize = 32768
        
        private let cSession: OpaquePointer
        private let sftpHandle: OpaquePointer
        private var buffer = [Int8](repeating: 0, count: SFTPHandle.bufferSize)

        init(cSession: OpaquePointer, sftpSession: OpaquePointer, remotePath: String, flags: Int32, mode: Int32, opt: Int32 = LIBSSH2_SFTP_OPENFILE) throws {
            guard let sftpHandle = libssh2_sftp_open_ex(
                sftpSession,
                remotePath,
                UInt32(remotePath.count),
                UInt(flags),
                Int(mode),
                    opt) else {
                    throw SSHError.mostRecentError(session: cSession, backupMessage: "libssh2_sftp_open_ex failed")
            }
            self.cSession = cSession
            self.sftpHandle = sftpHandle
        }
        
        func readNext(_ attrs: inout LIBSSH2_SFTP_ATTRIBUTES) -> ReadWriteProcessor.ReadResult {
            let result = libssh2_sftp_readdir_ex(sftpHandle, &buffer, SFTPHandle.bufferSize, nil, 0, &attrs)
            return ReadWriteProcessor.processRead(result: Int(result), buffer: &buffer, session: cSession)
        }

        func read(buffer: UnsafeMutablePointer<Int8>, maxLength len: Int) -> ReadWriteProcessor.ReadResult {
            let result = libssh2_sftp_read(sftpHandle, buffer, len)
            return ReadWriteProcessor.processRead(result: result, session: cSession)
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
        
    init(cSession: OpaquePointer) throws {
        guard let sftpSession = libssh2_sftp_init(cSession) else {
            throw SSHError.mostRecentError(session: cSession, backupMessage: "libssh2_sftp_init failed")
        }
        self.cSession = cSession
        self.sftpSession = sftpSession
    }

    
    
    public func dir(remotePath: String) throws -> [String:LIBSSH2_SFTP_ATTRIBUTES]  {
        let sftpHandle = try SFTPHandle(
                cSession: cSession,
                sftpSession: sftpSession,
                remotePath: remotePath,
                flags: LIBSSH2_FXF_READ,
                mode: 0,
                opt: LIBSSH2_SFTP_OPENDIR
        )

        var files = [String:LIBSSH2_SFTP_ATTRIBUTES]()
        var attrs = LIBSSH2_SFTP_ATTRIBUTES()

        var dataLeft = true
        while dataLeft {
            switch sftpHandle.readNext(&attrs) {
            case .data(let dataResult):
                switch dataResult {
                case .data(let data):
                    let name = String(data: data, encoding: .utf8)!
                    files[name] = attrs
                case .len:
                    fatalError("impossible state")
                }

            case .done:
                dataLeft = false
            case .eagain:
                break
            case .error(let error):
                throw error
            }
        }
        return files
    }

    public func remove(_ path: String) throws {
        let result = libssh2_sftp_unlink_ex(sftpSession, path, UInt32(path.count))
        if result != 0 {
            throw SSHError.codeError(code: Int32(result), session: cSession)
        }
    }

    /// Download a file from the remote server to the local device
    ///
    /// - Parameters:
    ///   - remotePath: the path to the existing file on the remote server to download
    ///   - localURL: the location on the local device whether the file should be downloaded to
    /// - Throws: SSHError if file can't be created or download fails
    public func download(remotePath: String, localURL: URL) throws {
        let sftpHandle = try SFTPHandle(
            cSession: cSession,
            sftpSession: sftpSession,
            remotePath: remotePath,
            flags: LIBSSH2_FXF_READ,
            mode: 0
        )
        
        guard FileManager.default.createFile(atPath: localURL.path, contents: nil, attributes: nil),
            let fileHandle = try? FileHandle(forWritingTo: localURL) else {
            throw SSHError.genericError("couldn't create file at \(localURL.path)")
        }
        
        defer { fileHandle.closeFile() }

        var dataLeft = true
        while dataLeft {
            switch sftpHandle.read() {
            case .data(let dataResult):
                switch dataResult {
                case .data(let data):
                    fileHandle.write(data)
                case .len:
                    fatalError("impossible state")
                }
            case .done:
                dataLeft = false
            case .eagain:
                break
            case .error(let error):
                throw error
            }
        }
    }

    private class SFTPInputStream: InputStream {
        var sftpHandle: SFTPHandle!
        private var lock = Lock()
        private var bytesAvailable = true

        public init(){
            super.init(data: Data())
        }

        override func open() {
        }

        override func close() {
            lock.lock()
            bytesAvailable = false
            lock.unlock()
        }

        override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {

            let opaquePtr = OpaquePointer(buffer)
            let int8pointer = UnsafeMutablePointer<Int8>(opaquePtr)
            let res = self.sftpHandle.read(buffer: int8pointer , maxLength: len)

            while true {
                switch res {
                case .data(let dataResult):
                    guard bytesAvailable else {
                        return 0
                    }
                    switch dataResult {
                    case .data:
                        fatalError("impossible state!")
                    case .len(let len):
                        return len
                    }
                case .done:
                    lock.lock()
                    bytesAvailable = false
                    lock.unlock()
                    return 0
                case .eagain:
                    Thread.sleep(forTimeInterval: 0.1)
                    break
                case .error:
                    return 0
                }
            }
        }

        override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
            return false
        }

        override var hasBytesAvailable: Bool {
            lock.lock()
            defer {
                lock.unlock()
            }
            return bytesAvailable
        }
    }


    public func download(remotePath: String) throws -> InputStream {
        let sftpHandle = try SFTPHandle(
                cSession: cSession,
                sftpSession: sftpSession,
                remotePath: remotePath,
                flags: LIBSSH2_FXF_READ,
                mode: 0
        )

        let stream =  SFTPInputStream()
        stream.sftpHandle = sftpHandle
        return stream
    }

    
    /// Upload a file from the local device to the remote server
    ///
    /// - Parameters:
    ///   - localURL: the path to the existing file on the local device
    ///   - remotePath: the location on the remote server whether the file should be uploaded to
    ///   - permissions: the file permissions to create the new file with; defaults to FilePermissions.default
    /// - Throws: SSHError if local file can't be read or upload fails
    public func upload(localURL: URL, remotePath: String, permissions: FilePermissions = .default) throws {
        let sftpHandle = try SFTPHandle(
            cSession: cSession,
            sftpSession: sftpSession,
            remotePath: remotePath,
            flags: LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT,
            mode: LIBSSH2_SFTP_S_IFREG | permissions.rawValue
        )
        
        let data = try Data(contentsOf: localURL, options: .alwaysMapped)
        
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
    
    deinit {
        libssh2_sftp_shutdown(sftpSession)
    }
    
}
