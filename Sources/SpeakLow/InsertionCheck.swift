import Foundation

/// Evidence from the original editor, captured immediately before sending a write.
struct InsertionCheck {
    let value: String?
    let selection: NSRange?
    let count: Int?

    func confirms(_ text: String, valueAfter: String?, caret: NSRange?, countAfter: Int?,
                  readRange: (NSRange) -> String?) -> Bool {
        let length = (text as NSString).length
        guard length > 0 else { return false }
        if let before = value, let after = valueAfter {
            let old = before as NSString
            if let selection {
                guard selection.location >= 0, selection.length >= 0, selection.location <= old.length,
                      selection.length <= old.length - selection.location else { return false }
                let expected = old.replacingCharacters(in: selection, with: text)
                guard expected == after else { return false }
                return before != after || (selection.length > 0 && caret == NSRange(location: selection.location + length, length: 0))
            }
            guard before != after else { return false }
            return matchesEdit(old, after as NSString, text: text, length: length)
        }

        // Some rich editors support character counts and ranged reads but no AXValue.
        guard let selection, let count, let countAfter,
              selection.location >= 0, selection.length >= 0, selection.location <= count,
              selection.length <= count - selection.location,
              countAfter == count - selection.length + length,
              caret == NSRange(location: selection.location + length, length: 0) else { return false }
        return readRange(NSRange(location: selection.location, length: length)) == text
    }

    // Without a reported selection, the two values must still differ by exactly
    // one replacement with the dictated text, leaving both surrounding parts intact.
    private func matchesEdit(_ old: NSString, _ new: NSString, text: String, length: Int) -> Bool {
        let remainder = new.length - length
        guard remainder >= 0, remainder <= old.length else { return false }
        var prefix = 0
        while prefix < remainder && old.character(at: prefix) == new.character(at: prefix) { prefix += 1 }
        var suffix = 0
        while suffix < remainder && old.character(at: old.length - 1 - suffix) == new.character(at: new.length - 1 - suffix) { suffix += 1 }
        let first = remainder - suffix
        guard first <= prefix else { return false }
        let candidates = NSRange(location: first, length: prefix - first + length)
        return new.range(of: text, options: .literal, range: candidates).location != NSNotFound
    }
}
