//
//  Error.swift
//  Shout
//
//  Created by Jake Heiser on 3/4/18.
//

import CSSH

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
    
    let rawCode: Int32
    let message: String
    
    var code: Code? {
        return Code(rawValue: -rawCode)
    }
    
    init(code: Int32, message: String) {
        self.rawCode = code
        self.message = message
    }
    
    init(code: Int32, session: OpaquePointer) {
        var messagePointer: UnsafeMutablePointer<Int8>? = nil
        var length: Int32 = 0
        libssh2_session_last_error(session, &messagePointer, &length, 0)
        let message = messagePointer.flatMap({ String.init(cString: $0) }) ?? "Error"
        self.init(code: code, message: message)
    }
    
}
