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
            welcomeController.show(status: accessibilityStatus, sandboxIntended: nil, sandboxDemo: nil,
                                   restoreLayoutID: nil, inputSource: nil)
            return
        }
        welcomeController.show(status: accessibilityStatus,
                               sandboxIntended: sandbox.intended,
                               sandboxDemo: sandbox.demo,
                               restoreLayoutID: sandbox.switchedFrom,
                               inputSource: inputSource)
    }

    /// Demo text for the welcome sandbox: always "shift happens" (user's
    /// decision). The Orchestrator fixes via `translate(selected, active →
    /// next)`, so the NEXT layout must produce Latin. If it doesn't, the input
    /// source is switched to the layout preceding a Latin one (restored when
    /// the welcome window closes).
    private func sandboxDemoText(inputSource: InputSourceService, keymaps: KeymapProvider)
        -> (intended: String, demo: String, switchedFrom: String?)? {
        let layouts = inputSource.enabledLayouts()
        guard layouts.count >= 2, let currentID = inputSource.currentLayoutID(),
              let currentIndex = layouts.firstIndex(where: { $0.id == currentID }) else { return nil }
        let demoText = WelcomeView.demoOriginal

        guard let latinIndex = layouts.firstIndex(where: { layoutID in
            keymaps.keymap(forSourceID: layoutID).map({ SandboxDemoText.canProduce(demoText, layout: $0) }) == true
        }) else { return nil } // no Latin-capable layout → no demo

        var activeID = currentID
        var switchedFrom: String? = nil
        if layouts[(currentIndex + 1) % layouts.count].id != layouts[latinIndex].id {
            activeID = layouts[(latinIndex - 1 + layouts.count) % layouts.count].id
            guard inputSource.selectLayout(id: activeID) else { return nil }
            switchedFrom = currentID
        }
        guard let demo = SandboxDemoText.generate(
            text: demoText,
            active: keymaps.keymap(forSourceID: activeID),
            next: keymaps.keymap(forSourceID: layouts[latinIndex].id)
        ) else { return nil }
        return (demoText, demo, switchedFrom)
    }

    func showSettings() { menuController.showSettings() }
}
