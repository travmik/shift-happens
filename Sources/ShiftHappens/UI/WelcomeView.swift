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
    /// Wrong-layout rendering of `demoOriginal`, or nil when the user's layouts
    /// cannot produce a usable demo (step 2 hidden).
    let sandboxDemo: String?
    let onStart: () -> Void

    @State private var sandboxEdited: String = ""

    init(status: AccessibilityStatus, sandboxDemo: String?, onStart: @escaping () -> Void) {
        self.status = status
        self.sandboxDemo = sandboxDemo
        self.onStart = onStart
        _sandboxEdited = State(initialValue: sandboxDemo ?? "")
    }

    private var sandboxFixed: Bool {
        sandboxEdited == Self.demoOriginal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
                Text("Shift Happens")
                    .font(.system(size: 17, weight: .semibold))
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

            if let sandboxDemo {
                stepRow(number: "2", done: sandboxFixed) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Try it right here")
                            .font(.system(size: 12, weight: .semibold))
                        Text("This text was typed in the wrong layout. Select it and press your hotkey.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                sandboxBox
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

    @ViewBuilder
    private var sandboxBox: some View {
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

    func show(status: AccessibilityStatus, sandboxDemo: String?) {
        self.status = status
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

        status.startPolling()

        let hosting = NSHostingView(rootView: WelcomeView(
            status: status,
            sandboxDemo: sandboxDemo,
            onStart: { [weak window] in window?.close() }
        ))
        hosting.sizingOptions = [.intrinsicContentSize]
        window.contentView = hosting
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        status?.stopPolling()
    }
}
