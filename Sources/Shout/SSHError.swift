//
//  SSHError.swift
//  Shout
//
//  Created by Jake Heiser on 3/6/18.
//

import Bindings

public struct SSHError: Swift.Error, CustomStringConvertible {
    
    private let libError: LibSSH2Error
    
    public var message: String {
        return libError.message
    }
    
    public var code: Code? {
        return libError.code
    }
    
    public var rawCode: Int32 {
        return libError.rawCode
    }
    
    public var description: String {
        let c: String
        if let code = code {
            c = "code \(rawCode) = " + String(describing: code)
        } else {
            c = "code \(rawCode)"
        }
        return "Error: \(message) (\(c))"
    }
    
    public init(libError: LibSSH2Error) {
        self.libError = libError
    }

}
