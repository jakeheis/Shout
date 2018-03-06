//
//  SSHAuthMethod.swift
//  Shout
//
//  Created by Jake Heiser on 3/4/18.
//

import Foundation
import Bindings

public protocol SSHAuthMethod {
    func authenticate(ssh: SSH, username: String) throws
}

public struct SSHPassword: SSHAuthMethod {
    
    let password: String
    
    public init(_ password: String) {
        self.password = password
    }
    
    public func authenticate(ssh: SSH, username: String) throws {
        try ssh.session.authenticate(username: username, password: password)
    }
    
}

public struct SSHAgent: SSHAuthMethod {
    
    public func authenticate(ssh: SSH, username: String) throws {
        let agent = try ssh.session.agent()
        try agent.connect()
        try agent.listIdentities()
        
        var last: Bindings.Agent.PublicKey? = nil
        var success: Bool = false
        while let identity = try agent.getIdentity(last: last) {
            if agent.authenticate(username: username, key: identity) {
                success = true
                break
            }
            last = identity
        }
        guard success else {
            throw LibSSH2Error(code: -1, message: "Failed to authenticate using the agent")
        }
    }
    
}

public struct SSHKey: SSHAuthMethod {
    
    public let privateKey: String
    public let publicKey: String
    public let passphrase: String?
    
    public init(privateKey: String, publicKey: String? = nil, passphrase: String? = nil) {
        self.privateKey = NSString(string: privateKey).expandingTildeInPath
        if let publicKey = publicKey {
            self.publicKey = NSString(string: publicKey).expandingTildeInPath
        } else {
            self.publicKey = self.privateKey + ".pub"
        }
        self.passphrase = passphrase
    }
    
    public func authenticate(ssh: SSH, username: String) throws {
        // If programatically given a passphrase, use it
        if let passphrase = passphrase {
            try ssh.session.authenticate(username: username,
                                             privateKey: privateKey,
                                             publicKey: publicKey,
                                             passphrase: passphrase)
            return
        }
        
        // Otherwise, try logging in without any passphrase
        do {
            try ssh.session.authenticate(username: username,
                                             privateKey: privateKey,
                                             publicKey: publicKey,
                                             passphrase: nil)
            return
        } catch {}
        
        // If that doesn't work, try using the Agent in case the passphrase has been saved there
        do {
            try SSHAgent().authenticate(ssh: ssh, username: username)
            return
        } catch {}
        
        // Finally, as a fallback, ask for the passphrase
        let enteredPassphrase = String(cString: getpass("Enter passphrase for \(privateKey) (empty for no passphrase):"))
        try ssh.session.authenticate(username: username,
                                         privateKey: privateKey,
                                         publicKey: publicKey,
                                         passphrase: enteredPassphrase)
    }
    
}

