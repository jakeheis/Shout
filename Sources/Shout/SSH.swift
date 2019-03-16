//
//  SSH.swift
//  Shout
//
//  Created by Jake Heiser on 3/4/18.
//

import Foundation
import Socket

public class SSH {
    
    public enum PtyType: String {
        case vanilla
        case vt100
        case vt102
        case vt220
        case ansi
        case xterm
    }
    
    public static func connect(host: String, port: Int32 = 22, username: String, authMethod: SSHAuthMethod, execution: (_ ssh: SSH) throws -> ()) throws {
        let ssh = try SSH(host: host, port: port)
        try ssh.authenticate(username: username, authMethod: authMethod)
        try execution(ssh)
    }
    
    let session: Session
    private let sock: Socket
    
    public var ptyType: PtyType? = nil
    
    public init(host: String, port: Int32 = 22) throws {
        self.sock = try Socket.create()
        self.session = try Session()
        
        session.blocking = 1
        try sock.connect(to: host, port: port)
        try session.handshake(over: sock)
    }
    
    public func authenticate(username: String, privateKey: String, publicKey: String? = nil, passphrase: String? = nil) throws {
        let key = SSHKey(privateKey: privateKey, publicKey: publicKey, passphrase: passphrase)
        try authenticate(username: username, authMethod: key)
    }
    
    public func authenticate(username: String, password: String) throws {
        try authenticate(username: username, authMethod: SSHPassword(password))
    }
    
    public func authenticateByAgent(username: String) throws {
        try authenticate(username: username, authMethod: SSHAgent())
    }
    
    public func authenticate(username: String, authMethod: SSHAuthMethod) throws {
        try authMethod.authenticate(ssh: self, username: username)
    }
    
    @discardableResult
    public func execute(_ command: String, silent: Bool = false) throws -> Int32 {
        return try execute(command, output: { (output) in
            if silent == false {
                print(output, terminator: "")
                fflush(stdout)
            }
        })
    }
    
    public func capture(_ command: String) throws -> (status: Int32, output: String) {
        var ongoing = ""
        let status = try execute(command) { (output) in
            ongoing += output
        }
        return (status, ongoing)
    }
    
    public func execute(_ command: String, output: ((_ output: String) -> ())) throws -> Int32 {
        let channel = try session.openCommandChannel()
        
        if let ptyType = ptyType {
            try channel.requestPty(type: ptyType.rawValue)
        }
        
        try channel.exec(command: command)
        
        var dataLeft = true
        while dataLeft {
            switch channel.readData() {
            case .data(let data):
                let str = data.withUnsafeBytes { (pointer: UnsafePointer<CChar>) in
                    return String(cString: pointer)
                }
                output(str)
            case .done:
                dataLeft = false
            case .eagain:
                break
            case .error(let error):
                throw error
            }
        }
        
        try channel.close()
        
        return channel.exitStatus()
    }
    
    @discardableResult
    public func sendFile(localURL: URL, remotePath: String, permissions: FilePermissions = .default) throws -> Int32 {
        guard let resources = try? localURL.resourceValues(forKeys: [.fileSizeKey]),
            let fileSize = resources.fileSize,
            let inputStream = InputStream(url: localURL) else {
                throw SSHError.genericError("couldn't open file at \(localURL)")
        }
        
        let channel = try session.openSCPChannel(fileSize: Int64(fileSize), remotePath: remotePath, permissions: permissions)
        
        inputStream.open()
        defer { inputStream.close() }
        
        let bufferSize = Int(Channel.packetDefaultSize)
        var buffer = Data(capacity: bufferSize)
        
        while inputStream.hasBytesAvailable {
            let bytesRead = buffer.withUnsafeMutableBytes { data in
                inputStream.read(data, maxLength: bufferSize)
            }
            if bytesRead == 0 { break }
            
            var bytesSent = 0
            while bytesSent < bytesRead {
                let chunk = bytesSent == 0 ? buffer : buffer.advanced(by: bytesSent)
                switch channel.write(data: chunk, length: bytesRead - bytesSent) {
                case .written(let count):
                    bytesSent += count
                case .eagain:
                    break
                case .error(let error):
                    throw error
                }
            }
        }
        
        try channel.sendEOF()
        try channel.waitEOF()
        try channel.close()
        try channel.waitClosed()
        
        return channel.exitStatus()
    }
    
    public func openSftp() throws -> SFTP {
        return try session.openSftp()
    }
    
}
