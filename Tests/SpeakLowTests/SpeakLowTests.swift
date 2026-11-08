import Foundation


private func singleTapTogglesOnlyOnRelease() {
    var tap = OptionTap()
    precondition(!tap.change(rightDown: true, otherModifier: false))
    precondition(!tap.change(rightDown: true, otherModifier: false))
    precondition(tap.change(rightDown: false, otherModifier: false))
    precondition(!tap.change(rightDown: false, otherModifier: false))
}

private func interruptedChordDoesNotToggleAndNextTapWorks() {
    var tap = OptionTap()
    _ = tap.change(rightDown: true, otherModifier: false)
    tap.interrupt()
    precondition(!tap.change(rightDown: false, otherModifier: false))
    _ = tap.change(rightDown: true, otherModifier: true)
    precondition(!tap.change(rightDown: false, otherModifier: false))
    _ = tap.change(rightDown: true, otherModifier: false)
    precondition(tap.change(rightDown: false, otherModifier: false))
}

private final class Fixture: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let key = request.value(forHTTPHeaderField: "x-api-key") ?? ""
        let code = key == "denied" ? 401 : 200
        let body = key == "partial"
            ? #"{"content":[{"type":"text","text":"一半"}],"stop_reason":"max_tokens"}"#
            : #"{"content":[{"type":"text","text":"这个需求先别发。"}],"stop_reason":"end_turn"}"#
        let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func claudeCompletesOrRejectsUnusableResults() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [Fixture.self]
    let session = URLSession(configuration: config)
    let original = "这个需、需求先别发。"
    let result = try await Claude.clean(original, key: "ok", model: "fixture", using: session)
    precondition(result == "这个需求先别发。")
    for key in ["denied", "partial"] {
        do {
            _ = try await Claude.clean(original, key: key, model: "fixture", using: session)
            preconditionFailure("Incomplete or unauthorized response accepted")
        } catch is VoiceError { continue }
    }
}

@main
enum RegressionChecks {
    static func main() async throws {
        singleTapTogglesOnlyOnRelease()
        interruptedChordDoesNotToggleAndNextTapWorks()
        try await claudeCompletesOrRejectsUnusableResults()
        print("Passed standalone tap, chord interruption, cleanup, rejection and truncation checks.")
    }
}
