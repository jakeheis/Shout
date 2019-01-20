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
    
    public var ptyType: PtyType? = nil
    let sock: Socket
    let session: Shout.Session
    
    public init(host: String, port: Int32 = 22) throws {
        do {
            self.sock = try Socket.create()
            self.session = try Shout.Session()
            
            session.blocking = 1
            try sock.connect(to: host, port: port)
            try session.handshake(over: sock)
        } catch let error as LibSSH2Error {
            throw SSHError(libError: error)
        }
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
        do {
            try authMethod.authenticate(ssh: self, username: username)
        } catch let error as LibSSH2Error {
            throw SSHError(libError: error)
        }
    }
    
    @discardableResult
    public func execute(_ command: String) throws -> Int32 {
        return try execute(command, output: { (output) in
            print(output, terminator: "")
            fflush(stdout)
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
        do {
            let channel = try session.openChannel()
            
            if let ptyType = ptyType {
                try channel.requestPty(type: ptyType.rawValue)
            }
            
            try channel.exec(command: command)
            
            while true {
                let (data, bytes) = try channel.readData()
                if bytes == 0 {
                    break
                }
                
                let str = data.withUnsafeBytes { (pointer: UnsafePointer<CChar>) in
                    return String(cString: pointer)
                }
                output(str)
            }
            
            try channel.close()
            
            return channel.exitStatus()
        } catch let error as LibSSH2Error {
            throw SSHError(libError: error)
        }
    }
    
    public func openSftp() throws -> SFTP {
        return try session.openSftp()
    }

    public func sendFile(localURL: URL, remotePath: String, permissions: FilePermissions = .default) throws -> Int32 {
        let channel = try session.openSCPChannel(localURL: localURL, remotePath: remotePath, permissions: permissions)
        try channel.sendFile()
        return channel.exitStatus()
    }
}

// MARK: - Deprecations

public extension SSH {
    @available(*, deprecated, message: "SSH.Session has been renamed SSH")
    public typealias Session = SSH
    
    @available(*, deprecated, message: "SSH.AuthMethod has been renamed SSHAuthMethod")
    public typealias AuthMethod = SSHAuthMethod
    
    @available(*, deprecated, message: "SSH.Password has been renamed SSHPassword")
    public typealias Password = SSHPassword
    
    @available(*, deprecated, message: "SSH.Agent has been renamed SSHAgent")
    public typealias Agent = SSHAgent
    
    @available(*, deprecated, message: "SSH.Key has been renamed SSHKey")
    public typealias Key = SSHKey
}
