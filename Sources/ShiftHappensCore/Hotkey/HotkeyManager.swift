import Carbon.HIToolbox
import Foundation

private final class HotkeyContext {
    let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }
}

/// Registers a global hotkey via Carbon RegisterEventHotKey (spec §3.5),
/// supports live rebinding from Settings, and reports combination availability.
public final class HotkeyManager {

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var config: HotkeyConfig
    private let context: HotkeyContext

    private static let signature = OSType(0x4B_53_57_31) /* "KSW1" */

    public init(config: HotkeyConfig = .standard, handler: @escaping () -> Void) {
        self.config = config
        context = HotkeyContext(handler: handler)
    }

    public func install() -> Bool {
        register()
    }

    /// Rebinds to a new combination; restores the previous one if registration fails.
    @discardableResult
    public func rebind(to newConfig: HotkeyConfig) -> Bool {
        uninstall()
        let previous = config
        config = newConfig
        if register() {
            return true
        }
        config = previous
        _ = register()
        return false
    }

    /// Temporarily unregisters the hotkey — used while recording a new
    /// combination, because a registered Carbon hotkey swallows its keystroke
    /// system-wide and the recorder would never see it.
    public func suspend() {
        uninstall()
    }

    public func resume() {
        _ = register()
    }

    public func uninstall() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        hotKeyRef = nil
        eventHandlerRef = nil
    }

    private func register() -> Bool {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(context).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.hotkeyCallback,
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
        guard installStatus == noErr else { return false }

        var hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let registerStatus = RegisterEventHotKey(
            config.keyCode,
            config.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        return registerStatus == noErr
    }

    private static let hotkeyCallback: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return noErr }
        let context = unsafeBitCast(userData, to: HotkeyContext.self)
        var hotKeyID = EventHotKeyID()
        _ = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        context.handler()
        return noErr
    }
}
