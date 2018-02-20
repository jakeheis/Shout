import Foundation
import CSSH
import Socket

public struct LibSSH2Error: Swift.Error {
    
    static func checkOnRead(code: Int32, session: OpaquePointer) throws {
        if code < 0 {
            throw LibSSH2Error(code: code, session: session)
        }
    }
    
    static func check(code: Int32, session: OpaquePointer) throws {
        if code != 0 {
            throw LibSSH2Error(code: code, session: session)
        }
    }
    
    static func check(code: Int32, message: String) throws {
        if code != 0 {
            throw LibSSH2Error(code: code, message: message)
        }
    }
    
    let code: Int32
    let message: String
    
    init(code: Int32, message: String) {
        self.code = code
        self.message = message
    }
    
    init(code: Int32, session: OpaquePointer) {
        var messagePointer: UnsafeMutablePointer<Int8>? = nil
        var length: Int32 = 0
        libssh2_session_last_error(session, &messagePointer, &length, 0)
        let message = messagePointer == nil ?  "Error" : String(cString: messagePointer!)
        self.init(code: code, message: message)
    }
    
}

class RawSession {
    
    private static let initResult = libssh2_init(0)
    
    fileprivate let cSession: OpaquePointer
    
    var rawAgent: RawAgent?
    
    var blocking: Int32 {
        get {
            return libssh2_session_get_blocking(cSession)
        }
        set(newValue) {
            libssh2_session_set_blocking(cSession, newValue)
        }
    }
    
    init() throws {
        try LibSSH2Error.check(code: RawSession.initResult, message: "libssh2_init failed")
        
        guard let cSession = libssh2_session_init_ex(nil, nil, nil, nil) else {
            throw LibSSH2Error(code: -1, message: "libssh2_session_init failed")
        }
        
        self.cSession = cSession
    }
    
    func handshake(over socket: Socket) throws {
        let code = libssh2_session_handshake(cSession, socket.socketfd)
        try LibSSH2Error.check(code: code, session: cSession)
    }
    
    func authenticate(username: String, privateKey: String, publicKey: String, passphrase: String?) throws {
        let code = libssh2_userauth_publickey_fromfile_ex(cSession,
                                                          username,
                                                          UInt32(username.count),
                                                          publicKey,
                                                          privateKey,
                                                          passphrase)
        try LibSSH2Error.check(code: code, session: cSession)
    }
    
    func authenticate(username: String, password: String) throws {
        let code = libssh2_userauth_password_ex(cSession,
                                                username,
                                                UInt32(username.count),
                                                password,
                                                UInt32(password.count),
                                                nil)
        try LibSSH2Error.check(code: code, session: cSession)
    }
    
    func openChannel() throws -> RawChannel {
        return try RawChannel(rawSession: self)
    }
    
    func agent() throws -> RawAgent {
        if let rawAgent = rawAgent {
            return rawAgent
        }
        let newAgent = try RawAgent(rawSession: self)
        rawAgent = newAgent
        return newAgent
    }
    
    deinit {
        libssh2_session_free(cSession)
    }
    
}

class RawChannel {
    
    private static let session = "session"
    private static let exec = "exec"
    
    private static let windowDefault: UInt32 = 2 * 1024 * 1024
    private static let packetDefault: UInt32 = 32768
    private static let bufferSize = 0x4000
    
    private let cSession: OpaquePointer
    private let cChannel: OpaquePointer
    
    init(rawSession: RawSession) throws {
        guard let cChannel = libssh2_channel_open_ex(rawSession.cSession,
                                                     RawChannel.session,
                                                     UInt32(RawChannel.session.count),
                                                     RawChannel.windowDefault,
                                                     RawChannel.packetDefault, nil, 0) else {
                                                        throw LibSSH2Error(code: -1, session: rawSession.cSession)
        }
        self.cSession = rawSession.cSession
        self.cChannel = cChannel
    }
    
    func requestPty(type: SSH.PtyType) throws {
        let code = libssh2_channel_request_pty_ex(cChannel,
                                                  type.rawValue, UInt32(type.rawValue.utf8.count),
                                                  nil, 0,
                                                  LIBSSH2_TERM_WIDTH, LIBSSH2_TERM_HEIGHT,
                                                  LIBSSH2_TERM_WIDTH_PX, LIBSSH2_TERM_WIDTH_PX)
        try LibSSH2Error.check(code: code, session: cSession)
    }
    
    func exec(command: String) throws {
        let code = libssh2_channel_process_startup(cChannel,
                                                   RawChannel.exec,
                                                   UInt32(RawChannel.exec.count),
                                                   command,
                                                   UInt32(command.count))
        try LibSSH2Error.check(code: code, session: cSession)
    }
    
    func readData() throws -> (data: Data, bytes: Int) {
        var data = Data(repeating: 0, count: RawChannel.bufferSize)
        
        let rc: Int = data.withUnsafeMutableBytes { (buffer: UnsafeMutablePointer<Int8>) in
            return libssh2_channel_read_ex(cChannel, 0, buffer, data.count)
        }
        
        try LibSSH2Error.checkOnRead(code: Int32(rc), session: cSession)
        
        return (data, rc)
    }
    
    func close() throws {
        let code = libssh2_channel_close(cChannel)
        try LibSSH2Error.check(code: code, session: cSession)
    }
    
    func waitClosed() throws {
        let code2 = libssh2_channel_wait_closed(cChannel)
        try LibSSH2Error.check(code: code2, session: cSession)
    }
    
    func exitStatus() -> Int32 {
        return libssh2_channel_get_exit_status(cChannel)
    }
    
    deinit {
        libssh2_channel_free(cChannel)
    }
    
}

class RawAgent {
    
    private let cSession: OpaquePointer
    private let cAgent: OpaquePointer
    
    init(rawSession: RawSession) throws {
        guard let cAgent = libssh2_agent_init(rawSession.cSession) else {
            throw LibSSH2Error(code: -1, session: rawSession.cSession)
        }
        self.cSession = rawSession.cSession
        self.cAgent = cAgent
    }
    
    func connect() throws {
        let code = libssh2_agent_connect(cAgent)
        try LibSSH2Error.check(code: code, session: cSession)
    }
    
    func listIdentities() throws {
        let code = libssh2_agent_list_identities(cAgent)
        try LibSSH2Error.check(code: code, session: cSession)
    }
    
    func getIdentity(last: RawAgentPublicKey?) throws -> RawAgentPublicKey? {
        var publicKeyOptional: UnsafeMutablePointer<libssh2_agent_publickey>? = nil
        let code = libssh2_agent_get_identity(cAgent, UnsafeMutablePointer(mutating: &publicKeyOptional), last?.cIdentity)
        
        if code == 1 { // No more identities
            return nil
        }
        
        try LibSSH2Error.check(code: code, session: cSession)
        
        guard let publicKey = publicKeyOptional else {
            throw LibSSH2Error(code: -1, message: "libssh2_agent_get_identity failed")
        }
        
        return RawAgentPublicKey(cIdentity: publicKey)
    }
    
    func authenticate(username: String, key: RawAgentPublicKey) -> Bool {
        let code = libssh2_agent_userauth(cAgent, username, key.cIdentity)
        return code == 0
    }
    
    deinit {
        libssh2_agent_disconnect(cAgent)
        libssh2_agent_free(cAgent)
    }
    
}

class RawAgentPublicKey {
    
    fileprivate let cIdentity: UnsafeMutablePointer<libssh2_agent_publickey>
    
    init(cIdentity: UnsafeMutablePointer<libssh2_agent_publickey>) {
        self.cIdentity = cIdentity
    }
    
}

extension RawAgentPublicKey: CustomStringConvertible {
    
    var description: String {
        return "Public key: " + String(cString: cIdentity.pointee.comment)
    }
    
}
