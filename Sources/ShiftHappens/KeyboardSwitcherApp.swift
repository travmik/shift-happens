import SwiftUI
import ShiftHappensCore

@main
struct ShiftHappensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("Settings…") { appDelegate.showSettings() }
            Divider()
            Button("Quit Shift Happens") { NSApp.terminate(nil) }
        } label: {
            if let image = Self.menuBarImage {
                Image(nsImage: image)
            } else {
                Image(systemName: "keyboard")
            }
        }
        .menuBarExtraStyle(.menu)
    }

    /// App icon as a menu bar template image — the system tints it for dark
    /// and light menu bars. Falls back to the SF Symbol when the bundle has no
    /// resources (e.g. `swift run`).
    private static let menuBarImage: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MenuBarIconTemplate", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }()
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var orchestrator: Orchestrator?
    private var hotkeyManager: HotkeyManager?
    private let menuController = MenuController()
    private let accessibilityStatus = AccessibilityStatus()
    private let welcomeController = WelcomeWindowController()

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
        menuController.configure(settings: settings, inputSource: inputSource, hotkey: hotkey,
                                 loginItem: loginItem, accessibilityStatus: accessibilityStatus)

        showWelcomeIfNeeded(inputSource: inputSource, keymaps: keymaps)
    }

    /// First-run onboarding: shown only when Accessibility is missing at launch
    /// (spec: welcome-onboarding — never nags after a granted launch).
    private func showWelcomeIfNeeded(inputSource: InputSourceService, keymaps: KeymapProvider) {
        guard !accessibilityStatus.granted else { return }
        guard let sandbox = sandboxDemoText(inputSource: inputSource, keymaps: keymaps) else {
            welcomeController.show(status: accessibilityStatus, sandboxIntended: nil, sandboxDemo: nil)
            return
        }
        welcomeController.show(status: accessibilityStatus,
                               sandboxIntended: sandbox.intended,
                               sandboxDemo: sandbox.demo)
    }

    /// Demo text for the welcome sandbox. The Orchestrator fixes text via
    /// `translate(selected, active → next)`, so the sandbox must contain the
    /// intended string *as the next layout produces it*. Tries candidates:
    /// the app name (works when the next layout produces Latin), then common
    /// Cyrillic greetings (the ghbdtn-style story) — first producible wins.
    private func sandboxDemoText(inputSource: InputSourceService, keymaps: KeymapProvider)
        -> (intended: String, demo: String)? {
        let layouts = inputSource.enabledLayouts()
        guard layouts.count >= 2, let currentID = inputSource.currentLayoutID(),
              let index = layouts.firstIndex(where: { $0.id == currentID }) else { return nil }
        let next = layouts[(index + 1) % layouts.count]
        guard let activeKeymap = keymaps.keymap(forSourceID: currentID),
              let nextKeymap = keymaps.keymap(forSourceID: next.id) else { return nil }
        for candidate in [WelcomeView.demoOriginal, "привіт", "привет"] {
            if let demo = SandboxDemoText.generate(text: candidate,
                                                   active: activeKeymap,
                                                   next: nextKeymap) {
                return (candidate, demo)
            }
        }
        return nil
    }

    func showSettings() { menuController.showSettings() }
}
