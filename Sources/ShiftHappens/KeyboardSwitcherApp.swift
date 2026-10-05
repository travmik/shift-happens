import SwiftUI
import ShiftHappensCore

@main
struct ShiftHappensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Shift Happens", systemImage: "keyboard") {
            Button("Settings…") { appDelegate.showSettings() }
            Divider()
            Button("Quit Shift Happens") { NSApp.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var orchestrator: Orchestrator?
    private var hotkeyManager: HotkeyManager?
    private let menuController = MenuController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let inputSource = InputSourceService()
        let settings = SettingsStore()
        let loginItem = LoginItemService()
        let textSelection = TextSelectionService(shouldRestoreClipboard: {
            settings.load().restoreClipboardAfterFix
        })
        let keymaps = KeymapProvider()
        orchestrator = Orchestrator(
            inputSource: inputSource,
            textSelection: textSelection,
            keymaps: keymaps,
            settings: settings
        )

        let hotkey = HotkeyManager(config: settings.load().hotkey ?? .standard) { [weak orchestrator] in
            orchestrator?.switchAndTranslate()
        }
        let installed = hotkey.install()
        if !installed {
            logError("failed to register hotkey option-command-K")
        }
        hotkeyManager = hotkey
        menuController.configure(settings: settings, inputSource: inputSource, hotkey: hotkey, loginItem: loginItem)
    }

    func showSettings() { menuController.showSettings() }
}
