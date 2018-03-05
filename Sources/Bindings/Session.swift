//
//  Session.swift
//  Bindings
//
//  Created by Jake Heiser on 3/4/18.
//

import CSSH
import Socket

public class Session {
    
    private static let initResult = libssh2_init(0)
    
    private let cSession: OpaquePointer
    private var _agent: Agent?
    
    public var blocking: Int32 {
        get {
            return libssh2_session_get_blocking(cSession)
        }
        set(newValue) {
            libssh2_session_set_blocking(cSession, newValue)
        }
    }
    
    public init() throws {
        try LibSSH2Error.check(code: Session.initResult, message: "libssh2_init failed")
        
        guard let cSession = libssh2_session_init_ex(nil, nil, nil, nil) else {
            throw LibSSH2Error(code: -1, message: "libssh2_session_init failed")
        }
        
        self.cSession = cSession
    }
    
    public func handshake(over socket: Socket) throws {
        let code = libssh2_session_handshake(cSession, socket.socketfd)
        try LibSSH2Error.check(code: code, session: cSession)
    }
    
    public func authenticate(username: String, privateKey: String, publicKey: String, passphrase: String?) throws {
        let code = libssh2_userauth_publickey_fromfile_ex(cSession,
                                                          username,
                                                          UInt32(username.count),
                                                          publicKey,
                                                          privateKey,
                                                          passphrase)
        try LibSSH2Error.check(code: code, session: cSession)
    }
    
    public func authenticate(username: String, password: String) throws {
        let code = libssh2_userauth_password_ex(cSession,
                                                username,
                                                UInt32(username.count),
                                                password,
                                                UInt32(password.count),
                                                nil)
        try LibSSH2Error.check(code: code, session: cSession)
    }
    
    public func openChannel() throws -> Channel {
        return try Channel(cSession: cSession)
    }
    
    public func agent() throws -> Agent {
        if let agent = _agent {
            return agent
        }
        let newAgent = try Agent(cSession: cSession)
        _agent = newAgent
        return newAgent
    }
    
    deinit {
        libssh2_session_free(cSession)
    }
    
}
