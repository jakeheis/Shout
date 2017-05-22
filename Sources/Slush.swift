import Foundation
import CSSH

struct SockAddr {
    
    let raw: Data
    
    // 1 byte sin_family
    // 2 byte sin_port
    // 4 byte sin_addr
    
//    var sinFamily:
    
    init(raw: Data) {
        self.raw = raw
    }
    
}

struct HostAddresses {
    
    let addresses: [Data]

    init?(host: String) {
        let components = host.components(separatedBy: " ")
        let address = components[0]
        
        let hostRef = CFHostCreateWithName(kCFAllocatorDefault, address as CFString).takeRetainedValue()
        CFHostStartInfoResolution(hostRef, .addresses, nil)
        guard let a = CFHostGetAddressing(hostRef, nil)?.takeUnretainedValue() else {
            return nil
        }
        
        guard let b = a as? [Data] else {
            print("NAH")
            return nil
        }
        self.addresses = b
        print(b[0] as NSData)
    }
    
}

class Session {

    typealias RawSession = OpaquePointer

    static let initResult = libssh2_init(0)
    
    let rawSession: RawSession

    init() {
        rawSession = libssh2_session_init_ex(nil, nil, nil, nil)
//        struct sockaddr_in a;
        // TODO: IPV6
        let socket = CFSocketCreate(kCFAllocatorDefault, AF_INET, SOCK_STREAM, IPPROTO_IP, 0, nil, nil)
        
        guard let hostAddresses = HostAddresses(host: "google.com") else {
            print("nah")
            return
        }

        let hostAddress = hostAddresses.addresses[0]

        hostAddress.withUnsafeBytes { (sockaddr: UnsafePointer<sockaddr>) in
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(sockaddr, socklen_t(hostAddress.count),
                           &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                if let numAddress = String(validatingUTF8: hostname) {
                    print(numAddress)
                }
            }
        }
        
        
    
        print(socket as Any, hostAddresses as Any)
//        CFSocketConnectToAddress(socket, <#T##address: CFData!##CFData!#>, <#T##timeout: CFTimeInterval##CFTimeInterval#>)
        
//        var on = 1
//        setsockopt(CFSocketGetNative(socket), SOL_SOCKET, SO_NOSIGPIPE, &on, UInt32(size(of: int))))
        
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
