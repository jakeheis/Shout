import Foundation
import Socket

public class SSH {
    
    public enum AuthMethod {
        case key(Key)
        case password(String)
        case agent
    }
    
    public struct Key {
        let publicKey: String
        let privateKey: String
        let passphrase: String
    }
    
    private init() {}
    
    public static func connect(host: String, port: Int32 = 22, username: String, authMethod: AuthMethod, execution: (_ session: Session) throws -> ()) throws {
        let session = try Session(host: host, port: port)
        try session.authenticate(username: username, authMethod: authMethod)
        try execution(session)
    }
    
    public class Session {
        
        public enum Error: Swift.Error {
            case authError
        }
        
        private let sock: Socket
        private let rawSession: RawSession
        
        public init(host: String, port: Int32 = 22) throws {
            self.sock = try Socket.create()
            self.rawSession = try RawSession()
            
            rawSession.blocking = 1
            try sock.connect(to: host, port: port)
            try rawSession.handshake(over: sock)
        }
        
        public func authenticate(username: String, privateKey: String, publicKey: String? = nil, passphrase: String) throws {
            let key = SSH.Key(publicKey: publicKey ?? (privateKey + ".pub"), privateKey: privateKey, passphrase: passphrase)
            try authenticate(username: username, authMethod: .key(key))
        }
        
        public func authenticate(username: String, password: String) throws {
            try authenticate(username: username, authMethod: .password(password))
        }
        
        public func authenticateByAgent(username: String) throws {
            try authenticate(username: username, authMethod: .agent)
        }
        
        public func authenticate(username: String, authMethod: SSH.AuthMethod) throws {
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
                var success: Bool = false
                while let identity = try agent.getIdentity(last: last) {
                    if agent.authenticate(username: username, key: identity) {
                        success = true
                        break
                    }
                    last = identity
                }
                guard success else {
                    throw Error.authError
                }
            }
        }
        
        public func authenticate(username: String, authMethods: [SSH.AuthMethod]) throws {
            var success = false
            for method in authMethods {
                do {
                    try authenticate(username: username, authMethod: method)
                    success = true
                    break
                } catch {}
            }
            if !success {
                throw Error.authError
            }
        }
        
        public struct CommandExecutionResult {
            let exitStatus: Int32
            let output: String
        }
        
        public func execute(_ command: String) throws -> CommandExecutionResult {
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
            
            try channel.close()
            try channel.waitClosed()
            let exitStatus = channel.exitStatus()
            
            return CommandExecutionResult(exitStatus: exitStatus, output: output)
        }
        
    }
    
}
