import XCTest

extension SFTPTests {
    static let __allTests = [
        ("testDownload", testDownload),
        ("testUpload", testUpload),
    ]
}

extension ShoutTests {
    static let __allTests = [
        ("testCapture", testCapture),
        ("testConnect", testConnect),
        ("testSendFile", testSendFile),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SFTPTests.__allTests),
        testCase(ShoutTests.__allTests),
    ]
}
#endif
