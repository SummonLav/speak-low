import AppKit
import CoreGraphics
import IOKit.hidsystem

struct OptionTap {
    private var rightIsDown = false
    private var eligible = false
    mutating func interrupt() { eligible = false }
    mutating func change(rightDown: Bool, otherModifier: Bool) -> Bool {
        if rightDown && !rightIsDown {
            rightIsDown = true
            eligible = !otherModifier
        } else if !rightDown && rightIsDown {
            rightIsDown = false
            defer { eligible = false }
            return eligible && !otherModifier
        } else if otherModifier {
            eligible = false
        }
        return false
    }
}

final class ShortcutMonitor {
    var toggle: () -> Void = {}
    var cancel: () -> Void = {}
    var handlesEscape = false
    private var swallowingEscape = false
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var state = OptionTap()
    var running: Bool { tap != nil }

    func start() -> Bool {
        if tap != nil { return true }
        let types: [CGEventType] = [.flagsChanged, .keyDown, .keyUp, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, pointer in
            guard let pointer else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<ShortcutMonitor>.fromOpaque(pointer).takeUnretainedValue()
            return monitor.receive(type, event) ? Unmanaged.passUnretained(event) : nil
        }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap,
                                          options: .defaultTap, eventsOfInterest: mask, callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        tap = port
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
        state = OptionTap()
    }

    private func receive(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            state = OptionTap()
            swallowingEscape = false
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return true
        }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .flagsChanged && code == 61 {
            let flags = event.flags
            let left = flags.rawValue & UInt64(NX_DEVICELALTKEYMASK) != 0
            let right = flags.rawValue & UInt64(NX_DEVICERALTKEYMASK) != 0
            let down = right || (!left && flags.contains(.maskAlternate))
            let chord = left || !flags.intersection([.maskCommand, .maskControl, .maskShift, .maskSecondaryFn]).isEmpty
            if state.change(rightDown: down, otherModifier: chord) { DispatchQueue.main.async { self.toggle() } }
        } else {
            state.interrupt()
            if code == 53 && type == .keyDown && (handlesEscape || swallowingEscape) {
                if !swallowingEscape { DispatchQueue.main.async { self.cancel() } }
                swallowingEscape = true
                return false
            }
            if code == 53 && type == .keyUp && swallowingEscape {
                swallowingEscape = false
                return false
            }
        }
        return true
    }
}
