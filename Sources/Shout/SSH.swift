import Foundation
import Bindings
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
    
    private init() {}
    
    public static func connect(host: String, port: Int32 = 22, username: String, authMethod: SSH.AuthMethod, execution: (_ session: Session) throws -> ()) throws {
        let session = try Session(host: host, port: port)
        try session.authenticate(username: username, authMethod: authMethod)
        try execution(session)
    }
    
    public class Session {
        
        public var ptyType: PtyType? = nil
        
        private let sock: Socket
        let wrapped: Bindings.Session
        
        public init(host: String, port: Int32 = 22) throws {
            self.sock = try Socket.create()
            self.wrapped = try Bindings.Session()
            
            wrapped.blocking = 1
            try sock.connect(to: host, port: port)
            try wrapped.handshake(over: sock)
        }
        
        public func authenticate(username: String, privateKey: String, publicKey: String? = nil, passphrase: String? = nil) throws {
            let key = SSH.Key(privateKey: privateKey, publicKey: publicKey, passphrase: passphrase)
            try authenticate(username: username, authMethod: key)
        }
        
        public func authenticate(username: String, password: String) throws {
            try authenticate(username: username, authMethod: Password(password))
        }
        
        public func authenticateByAgent(username: String) throws {
            try authenticate(username: username, authMethod: Agent())
        }
        
        public func authenticate(username: String, authMethod: SSH.AuthMethod) throws {
            try authMethod.authenticate(username: username, session: self)
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
            let channel = try wrapped.openChannel()
            
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
        }
        
    }
    
}
