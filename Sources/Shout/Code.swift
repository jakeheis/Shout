//
//  Code.swift
//  Shout
//
//  Created by Jake Heiser on 3/6/18.
//

public enum Code: Int32 {
    case genericError = 1
    case bannerRecv
    case bannerSend
    case invalidMac
    case kexFailure // 5
    case alloc
    case socketSend
    case keyExchangeFailure
    case errorTimeout
    case hostkeyInit // 10
    case hostkeySign
    case decrypt
    case socketDisconnect
    case proto
    case passwordExpired // 15
    case file
    case methodNone
    case authenticationFailed
    case publicKeyUnverified
    case channelOutOfOrder // 20
    case channelFailure
    case channelRequestDenied
    case channelUnknown
    case channelWindowExceeded
    case channelPacketExceeded // 25
    case channelClosed
    case channelEofSent
    case scpProtocol
    case zlib
    case socketTimeout // 30
    case sftpProtocol
    case requestDenied
    case methodNotSupported
    case inval
    case invalidPollType // 35
    case publicKeyProtocol
    case eagain
    case bufferTooSmall
    case badUse
    case compress // 40
    case outOfBoundary
    case agentProtocol
    case socketRecv
    case encrypt
    case badSocket // 45
    case knownHosts
    case channelWindowFull
}
