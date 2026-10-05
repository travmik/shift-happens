import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// A global, consuming event tap used while recording a hotkey combination.
///
/// Recording owns the keyboard: every key-down is consumed (so system shortcuts
/// like ⌘Space don't fire and nothing leaks into the frontmost app) and forwarded
/// to the recorder. This is also what makes occupied *system* shortcuts (⌘Space,
/// ⇧⌘3…) observable at all — they are consumed upstream of app-local event
/// monitors and would otherwise never reach the recorder.
///
/// Start/stop must be called on the main thread; callbacks arrive on the main
/// run loop. The instance is a singleton, so the CGEvent tap's unretained
/// userInfo reference always stays valid.
public final class HotkeyRecordingTap {
    public static let shared = HotkeyRecordingTap()

    private var tap: CFMachPort?
    private var onKeyEvent: ((_ keyCode: UInt32, _ modifiers: UInt32) -> Void)?
    private var onModifiersChanged: ((_ modifiers: UInt32) -> Void)?
    private var onEscape: (() -> Void)?

    public init() {}

    public func start(keyEvent: @escaping (_ keyCode: UInt32, _ modifiers: UInt32) -> Void,
               modifiersChanged: @escaping (_ modifiers: UInt32) -> Void,
               escape: @escaping () -> Void) {
        guard tap == nil else { return }
        onKeyEvent = keyEvent
        onModifiersChanged = modifiersChanged
        onEscape = escape

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let tap = Unmanaged<HotkeyRecordingTap>.fromOpaque(userInfo).takeUnretainedValue()
            return tap.process(event: event, type: type)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(
                (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
            ),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logError("could not create hotkey recording tap — is Accessibility granted?")
            return
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    public func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        tap = nil
        onKeyEvent = nil
        onModifiersChanged = nil
        onEscape = nil
    }

    private func process(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = carbonModifiers(of: event.flags)
        if type == .flagsChanged {
            onModifiersChanged?(modifiers)
            return nil // modifier chatter is consumed and reported
        }
        if keyCode == 53 { // Esc cancels recording
            onEscape?()
            return nil
        }
        onKeyEvent?(keyCode, modifiers)
        return nil // recording owns the keyboard: consume every key-down
    }

    private func carbonModifiers(of flags: CGEventFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.maskCommand) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.maskAlternate) { modifiers |= UInt32(optionKey) }
        if flags.contains(.maskControl) { modifiers |= UInt32(controlKey) }
        if flags.contains(.maskShift) { modifiers |= UInt32(shiftKey) }
        return modifiers
    }
}
