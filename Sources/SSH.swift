import Foundation
import Socket

class SSH {
    
    let sock: Socket
    let rawSession: RawSession
    
    init(host: String, port: Int32 = 22) throws {
        self.sock = try Socket.create()
        self.rawSession = try RawSession()
        
        rawSession.blocking = 1
        try sock.connect(to: host, port: port)
        try rawSession.handshake(over: sock)
    }
    
    func authenticate(user: String, privateKey: String, publicKey: String? = nil, passphrase: String) throws {
        try rawSession.authenticate(user: user,
                                    privateKey: privateKey,
                                    publicKey: publicKey ?? (privateKey + ".pub"),
                                    passphrase: passphrase)
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
