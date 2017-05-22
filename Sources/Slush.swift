import Foundation
import CSSH
import Socket

class Session {

    typealias RawSession = OpaquePointer

    static let initResult = libssh2_init(0)
    
    let rawSession: RawSession

    init() {
        rawSession = libssh2_session_init_ex(nil, nil, nil, nil)
        
        do {
            let sock = try Socket.create()
            try sock.connect(to: "jakeheis.com", port: 22)
            
            libssh2_session_set_blocking(rawSession, 1);
            let result = libssh2_session_handshake(rawSession, sock.socketfd)
            print(result)
            
            let result2 = libssh2_userauth_publickey_fromfile_ex(rawSession, "root", 4, "/Users/jakeheiser/.ssh/id_rsa.pub", "/Users/jakeheiser/.ssh/id_rsa", "bnhHtg6VvdtUjseaGBWhfoQU")
            print(result2)
            
            let channel = libssh2_channel_open_ex(rawSession, "session", 7, 2*1024*1024, 32768, nil, 0)
            
            let result3 = libssh2_channel_process_startup(channel, "exec", 4, "ls -a", 5)
            print(result3)
            
            var rc = 0
            var byteCount = 0
            repeat {
                var data = Data(repeating: 0, count: 0x4000)
                
                rc = data.withUnsafeMutableBytes { (buffer: UnsafeMutablePointer<Int8>) in
                    return libssh2_channel_read_ex(channel, 0, buffer, 0x400)
                }
                
                if rc > 0 {
                    byteCount += rc
                    let str = data.withUnsafeBytes { (pointer: UnsafePointer<CChar>) in
                        return String(cString: pointer)
                    }
                    print(str)
                } else {
                    print("libssh2_channel_read returned \(rc)")
                }
            } while (rc > 0);
        } catch let error {
            print(error)
        }
        
    }

    deinit {
        libssh2_session_free(rawSession)
        
    }

}

/*

SSH.connect("1.1.1.1") { (connection) in
    connection.blah()
    connection.blah()
}

*/
