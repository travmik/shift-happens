import AppKit
import ApplicationServices
import SwiftUI
import ShiftHappensCore

/// NSWindow that can take key focus inside an LSUIElement (accessory) app —
/// plain NSWindow refuses to become key here, leaving the window unusable.
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// First-run onboarding (spec: welcome-onboarding): header, grant step with a
/// live status pill, and a self-demo sandbox — "shift happens" rendered in the
/// user's other layout, which the app fixes in place once Accessibility is on.
struct WelcomeView: View {
    static let demoOriginal = "shift happens"

    @ObservedObject var status: AccessibilityStatus
    /// The string the sandbox should fix into (e.g. "shift happens"); also the
    /// step-2 completion check. Nil when no demo is available.
    let sandboxIntended: String?
    /// `sandboxIntended` rendered through the active layout (the mistyped text).
    let sandboxDemo: String?
    let onStart: () -> Void

    @State private var sandboxEdited: String = ""

    init(status: AccessibilityStatus, sandboxIntended: String?, sandboxDemo: String?,
         onStart: @escaping () -> Void) {
        self.status = status
        self.sandboxIntended = sandboxIntended
        self.sandboxDemo = sandboxDemo
        self.onStart = onStart
        _sandboxEdited = State(initialValue: sandboxDemo ?? "")
    }

    private var sandboxFixed: Bool {
        sandboxEdited == Self.demoOriginal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 8) {
                appIconImage
                    .frame(width: 80, height: 80)
                    .frame(maxWidth: .infinity)
                Text("Shift Happens")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }

            stepRow(number: "1", done: status.granted) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Grant Accessibility")
                        .font(.system(size: 12, weight: .semibold))
                    HStack {
                        Text("Needed to read and fix your selected text.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        if status.granted {
                            statusPill("Granted", color: .green)
                        } else {
                            statusPill("Pending", color: .orange)
                        }
                    }
                    if !status.granted {
                        Button("Grant Accessibility…") {
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
                            _ = AXIsProcessTrustedWithOptions(options)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }

            if let sandboxDemo, let sandboxIntended {
                stepRow(number: "2", done: sandboxFixed) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Try it right here")
                            .font(.system(size: 12, weight: .semibold))
                        Text("This text was typed in the wrong layout. Select it and press your hotkey.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                sandboxBox(intended: sandboxIntended)
            }

            Button {
                onStart()
            } label: {
                Text("Get started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!status.granted)
        }
        .padding(18)
        .frame(width: 300)
        .onAppear { status.startPolling() }
    }

    /// The bundled app icon (present in the .app bundle); SF Symbol fallback
    /// for resource-less contexts like `swift run`.
    @ViewBuilder
    private var appIconImage: some View {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            Image(nsImage: icon)
                .resizable()
        } else {
            Image(systemName: "keyboard")
                .font(.system(size: 26))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
        }
    }

    @ViewBuilder
    private func sandboxBox(intended: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if status.granted {
                TextField("", text: $sandboxEdited)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
            } else {
                Text(sandboxEdited)
                    .font(.system(size: 15))
                    .foregroundStyle(.red)
            }
            Text(sandboxFixed
                 ? "✓ fixed — that's the whole app"
                 : "generated from your layouts")
                .font(.system(size: 10))
                .foregroundStyle(sandboxFixed ? Color.green : Color.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(sandboxFixed ? Color.green : Color.secondary.opacity(0.4),
                                      style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
        )
    }

    private func stepRow<Content: View>(number: String, done: Bool,
                                        @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(done ? "✓" : number)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(done ? Color.green : Color.secondary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(done ? Color.green.opacity(0.15) : Color.secondary.opacity(0.12)))
            content()
        }
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

/// Presents the welcome panel. The shared status polls only while a window
/// displaying it is visible: the welcome retains on open and releases on close.
@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var status: AccessibilityStatus?
    private var restoreLayoutID: String?
    private var inputSource: InputSourceServicing?

    func show(status: AccessibilityStatus, sandboxIntended: String?, sandboxDemo: String?,
              restoreLayoutID: String?, inputSource: InputSourceServicing?) {
        self.status = status
        self.restoreLayoutID = restoreLayoutID
        self.inputSource = inputSource
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Welcome to Shift Happens"
        window.delegate = self
        window.center()

        // Polling is retained by WelcomeView.onAppear (once) and released in
        // windowWillClose — do not retain here, or the ref-count never reaches
        // zero and the timer leaks past window close.

        let hosting = NSHostingView(rootView: WelcomeView(
            status: status,
            sandboxIntended: sandboxIntended,
            sandboxDemo: sandboxDemo,
            onStart: { [weak window] in window?.close() }
        ))
        hosting.sizingOptions = [.intrinsicContentSize]
        window.contentView = hosting
        self.window = window

        // Deferred so the SwiftUI layout pass has run; the window then adopts
        // the content's natural size (same pattern as the Settings window).
        DispatchQueue.main.async { [weak window] in
            guard let window,
                  let hosting = window.contentView as? NSHostingView<WelcomeView> else { return }
            hosting.layoutSubtreeIfNeeded()
            var size = hosting.fittingSize
            size.width = max(size.width, 300)
            size.height = max(size.height, 120)
            window.setContentSize(size)
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        status?.stopPolling()
        // Restore the layout the demo switched away from (option 3, user's
        // decision: the welcome forces a Latin-next layout so the sandbox can
        // always be "shift happens").
        if let restoreLayoutID, let inputSource {
            _ = inputSource.selectLayout(id: restoreLayoutID)
        }
        restoreLayoutID = nil
    }
}
