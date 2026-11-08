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

private func confirmsOnlyTheExpectedEdit() {
    // AX selection offsets are UTF-16, including text before a selected range.
    let before = InsertionCheck(value: "🍋苹果，苹果", selection: NSRange(location: 2, length: 2), count: nil)
    func confirmed(_ after: String) -> Bool {
        before.confirms("青柠", valueAfter: after, caret: nil, countAfter: nil) { _ in nil }
    }
    precondition(!confirmed("🍋苹果，苹果"))      // editor ignored the paste
    precondition(!confirmed("🍋苹果，青柠"))      // text appeared at a different position
    precondition(confirmed("🍋青柠，苹果"))
    let same = InsertionCheck(value: "一二", selection: NSRange(location: 1, length: 1), count: 2)
    precondition(!same.confirms("二", valueAfter: "一二", caret: same.selection, countAfter: 2) { _ in nil })
    precondition(same.confirms("二", valueAfter: "一二", caret: NSRange(location: 2, length: 0), countAfter: 2) { _ in nil })

    let rich = InsertionCheck(value: "前🌿后", selection: nil, count: nil)
    precondition(rich.confirms("测试", valueAfter: "前测试后", caret: nil, countAfter: nil) { _ in nil })
    precondition(!rich.confirms("前", valueAfter: "前🌿错", caret: nil, countAfter: nil) { _ in nil })
    let ranged = InsertionCheck(value: nil, selection: NSRange(location: 1, length: 0), count: 2)
    let end = NSRange(location: 3, length: 0)
    precondition(!ranged.confirms("输入", valueAfter: nil, caret: end, countAfter: 4) { _ in nil })
    precondition(ranged.confirms("输入", valueAfter: nil, caret: end, countAfter: 4) {
        $0 == NSRange(location: 1, length: 2) ? "输入" : nil
    })
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
        confirmsOnlyTheExpectedEdit()
        try await claudeCompletesOrRejectsUnusableResults()
        print("Passed standalone tap, chord interruption, insertion confirmation, cleanup, rejection and truncation checks.")
    }
}
