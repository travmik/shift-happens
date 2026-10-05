import AppKit
import SwiftUI
import ShiftHappensCore

/// Owns the Settings window, hosting the SwiftUI carded view in an AppKit window
/// (spec §4: avoids SwiftUI window-lifecycle quirks inside MenuBarExtra-only apps).
/// About lives inside Settings as a card, so this is the only window.
@MainActor
final class MenuController {
    private var settingsStore: SettingsStore?
    private var inputSourceService: InputSourceServicing?
    private var hotkeyManager: HotkeyManager?
    private var loginItemService: LoginItemServicing?
    private var settingsWindow: NSWindow?

    func configure(settings: SettingsStore,
                   inputSource: InputSourceServicing,
                   hotkey: HotkeyManager,
                   loginItem: LoginItemServicing) {
        settingsStore = settings
        inputSourceService = inputSource
        hotkeyManager = hotkey
        loginItemService = loginItem
    }

    func showSettings() {
        guard let settingsStore, let inputSourceService, let hotkeyManager, let loginItemService else { return }
        let window: NSWindow
        if let existing = settingsWindow {
            window = existing
        } else {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 354, height: 320),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.title = "Shift Happens"
            window.center()
            settingsWindow = window
        }
        let hosting = NSHostingView(
            rootView: SettingsView(
                store: settingsStore,
                inputSource: inputSourceService,
                hotkey: hotkeyManager,
                loginItem: loginItemService,
                onLayoutChange: { [weak window] in
                    // Deferred so the SwiftUI layout pass has run; degenerate sizes
                    // (view not laid out yet) are ignored.
                    DispatchQueue.main.async {
                        guard let window,
                              let hosting = window.contentView as? NSHostingView<SettingsView> else { return }
                        hosting.layoutSubtreeIfNeeded()
                        var size = hosting.fittingSize
                        size.width = max(size.width, 330)
                        size.height = max(size.height, 260)
                        window.setContentSize(size)
                    }
                }
            )
        )
        hosting.sizingOptions = [.intrinsicContentSize]
        window.contentView = hosting
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
