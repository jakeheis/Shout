import Foundation
import CSSH
import Socket

class Session {
    
    init() {
        do {
            let sock = try Socket.create()
            try sock.connect(to: "jakeheis.com", port: 22)
            
            let rawSession = try RawSession()
            rawSession.blocking = 1
            try rawSession.handshake(over: sock)
            
            try rawSession.authenticate(user: "", privateKey: "", passphrase: "")
            
            let channel = try rawSession.openChannel()
            
            try channel.exec(command: "ls -a")
            
            var byteCount = 0
            while true {
                let (data, bytes) = try channel.readData()
                if bytes == 0 {
                    break
                }
                
                if bytes > 0 {
                    byteCount += bytes
                    let str = data.withUnsafeBytes { (pointer: UnsafePointer<CChar>) in
                        return String(cString: pointer)
                    }
                    print(str)
                } else {
                    print("libssh2_channel_read returned \(bytes)")
                }
            }
        } catch let error {
            print(error)
        }
        
    }

}

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
    
    static let initResult = libssh2_init(0)
    
    let cSession: OpaquePointer
    
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
    
    func authenticate(user: String, privateKey: String, publicKey: String? = nil, passphrase: String) throws {
        let code = libssh2_userauth_publickey_fromfile_ex(cSession,
                                                          user,
                                                          UInt32(user.characters.count),
                                                          publicKey ?? (privateKey + ".pub"),
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
    
    static let session = "session"
    static let exec = "exec"
    
    static let windowDefault: UInt32 = 2 * 1024 * 1024
    static let packetDefault: UInt32 = 32768
    
    let cChannel: OpaquePointer
    
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

/*

SSH.connect("1.1.1.1") { (connection) in
    connection.blah()
    connection.blah()
}

*/
