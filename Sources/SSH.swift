import Foundation
import Socket

class SSH {
    
    let sock: Socket
    let rawSession: RawSession

    enum AuthMethod {
        case key(Key)
        case password(String)
        case agent
    }

    struct Key {
        let publicKey: String
        let privateKey: String
        let passphrase: String
    }
    
    init(host: String, port: Int32 = 22) throws {
        self.sock = try Socket.create()
        self.rawSession = try RawSession()
        
        rawSession.blocking = 1
        try sock.connect(to: host, port: port)
        try rawSession.handshake(over: sock)
    }
    
    func authenticate(username: String, privateKey: String, publicKey: String? = nil, passphrase: String) throws {
        let key = Key(publicKey: publicKey ?? (privateKey + ".pub"), privateKey: privateKey, passphrase: passphrase)
        try authenticate(username: username, authMethod: .key(key))
    }
    
    func authenticate(username: String, password: String) throws {
        try authenticate(username: username, authMethod: .password(password))
    }
    
    func authenticateByAgent(username: String) throws {
        try authenticate(username: username, authMethod: .agent)
    }

    func authenticate(username: String, authMethod: AuthMethod) throws {
        switch authMethod {
        case let .key(key):
            try rawSession.authenticate(username: username,
                                        privateKey: key.privateKey,
                                        publicKey: key.publicKey,
                                        passphrase: key.passphrase)
        case let .password(password):
            try rawSession.authenticate(username: username, password: password)
        case .agent:
            let agent = try rawSession.agent()
            try agent.connect()
            try agent.listIdentities()
            
            var last: RawAgentPublicKey? = nil
            while let identity = try agent.getIdentity(last: last) {
                if agent.authenticate(username: username, key: identity) {
                    break
                }
                last = identity
            }
        }
    }
    
    func execute(_ command: String) throws -> String {
        let channel = try rawSession.openChannel()
        try channel.exec(command: command)
        
        var output = ""
        while true {
            let (data, bytes) = try channel.readData()
            if bytes == 0 {
                break
            }
            
            if bytes > 0 {
                let str = data.withUnsafeBytes { (pointer: UnsafePointer<CChar>) in
                    return String(cString: pointer)
                }
                output += str
            } else {
                throw LibSSH2Error.error(Int32(bytes))
            }
        }
        return output
    }
    
}

/*
 
 SSH.connect("1.1.1.1") { (connection) in
 connection.blah()
 connection.blah()
 }
 
 */
