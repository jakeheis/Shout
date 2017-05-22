import Foundation
import CSSH
import Socket

enum LibSSH2Error: Swift.Error {
    case error(Int32)
    case initializationError
    
    static func check(code: Int32) throws {
        if code != 0 {
            throw LibSSH2Error.error(code)
        }
    }
}

class RawSession {
    
    private static let initResult = libssh2_init(0)
    
    fileprivate let cSession: OpaquePointer
    
    var blocking: Int32 {
        get {
            return libssh2_session_get_blocking(cSession)
        }
        set(newValue) {
            libssh2_session_set_blocking(cSession, newValue)
        }
    }
    
    init() throws {
        try LibSSH2Error.check(code: RawSession.initResult)
        
        guard let cSession = libssh2_session_init_ex(nil, nil, nil, nil) else {
            throw LibSSH2Error.initializationError
        }
        
        self.cSession = cSession
    }
    
    func handshake(over socket: Socket) throws {
        let code = libssh2_session_handshake(cSession, socket.socketfd)
        try LibSSH2Error.check(code: code)
    }
    
    func authenticate(user: String, privateKey: String, publicKey: String, passphrase: String) throws {
        let code = libssh2_userauth_publickey_fromfile_ex(cSession,
                                                          user,
                                                          UInt32(user.characters.count),
                                                          publicKey,
                                                          privateKey,
                                                          passphrase)
        try LibSSH2Error.check(code: code)
    }
    
    func openChannel() throws -> RawChannel {
        return try RawChannel(rawSession: self)
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
    
    private let cChannel: OpaquePointer
    
    init(rawSession: RawSession) throws {
        guard let cChannel = libssh2_channel_open_ex(rawSession.cSession,
                                           RawChannel.session,
                                           UInt32(RawChannel.session.characters.count),
                                           RawChannel.windowDefault,
                                           RawChannel.packetDefault, nil, 0) else {
            throw LibSSH2Error.initializationError
        }
        self.cChannel = cChannel
    }
    
    func exec(command: String) throws {
        let code = libssh2_channel_process_startup(cChannel,
                                        RawChannel.exec,
                                        UInt32(RawChannel.exec.characters.count),
                                        command,
                                        UInt32(command.characters.count))
        try LibSSH2Error.check(code: code)
    }
    
    func readData() throws -> (data: Data, bytes: Int) {
        var data = Data(repeating: 0, count: 0x4000)
        
        let rc: Int = data.withUnsafeMutableBytes { (buffer: UnsafeMutablePointer<Int8>) in
            return libssh2_channel_read_ex(cChannel, 0, buffer, 0x400)
        }
        
        if rc < 0 {
            throw LibSSH2Error.error(Int32(rc))
        }
        
        return (data, rc)
    }
    
    deinit {
        libssh2_channel_free(cChannel)
    }
    
}