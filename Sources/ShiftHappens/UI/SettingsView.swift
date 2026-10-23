import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI
import ShiftHappensCore

/// Carded settings surface: floating rounded cards on the window background —
/// Languages (summary, expands in place), Hotkey (expandable, records new
/// combinations), Accessibility status, Clipboard restore, and an inline About
/// card (spec §4).
struct SettingsView: View {
    let store: SettingsStore
    let inputSource: InputSourceServicing
    let hotkey: HotkeyManager
    let loginItem: LoginItemServicing
    @ObservedObject var status: AccessibilityStatus
    var onLayoutChange: () -> Void = {}

    @State private var layouts: [InputSourceInfo] = []
    @State private var enabledIDs: Set<String> = []
    @State private var restoreClipboard = false
    @State private var launchAtLogin = false
    @State private var languagesExpanded = false
    @State private var hotkeyExpanded = false
    @State private var currentHotkey: HotkeyConfig
    @State private var isRecording = false
    @State private var liveSymbols: [String] = []
    @State private var draftHotkey: HotkeyConfig?
    @State private var draftStatus: DraftStatus = .free
    @State private var recordingHint: String?

    enum DraftStatus: Equatable {
        case free
        case occupied(String)
    }

    init(store: SettingsStore,
         inputSource: InputSourceServicing,
         hotkey: HotkeyManager,
         loginItem: LoginItemServicing,
         accessibilityStatus: AccessibilityStatus,
         onLayoutChange: @escaping () -> Void = {}) {
        self.store = store
        self.inputSource = inputSource
        self.hotkey = hotkey
        self.loginItem = loginItem
        self.status = accessibilityStatus
        self.onLayoutChange = onLayoutChange
        _currentHotkey = State(initialValue: store.load().hotkey ?? .standard)
    }

    var body: some View {
        VStack(spacing: 10) {
            languagesCard
            hotkeyCard
            accessibilityCard
            clipboardCard
            launchAtLoginCard
            aboutCard
        }
        .padding(12)
        .frame(width: 330)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            reload()
            // Live status: the pill updates while Settings is visible (spec:
            // welcome-onboarding — fixes the stale one-shot read).
            status.startPolling()
        }
        .onDisappear { status.stopPolling() }
        .onChange(of: languagesExpanded) { _ in onLayoutChange() }
        .onChange(of: hotkeyExpanded) { _ in onLayoutChange() }
        .onChange(of: isRecording) { recording in
            // A registered Carbon hotkey swallows its keystroke system-wide, so it
            // must be unregistered while recording — otherwise the current
            // combination can never be re-recorded.
            if recording {
                hotkey.suspend()
                startRecording()
            } else {
                stopRecording()
                hotkey.resume()
            }
            onLayoutChange()
        }
        .onDisappear {
            // Safety net: closing the window mid-recording must not leave the
            // global hotkey suspended or the event tap installed.
            HotkeyRecordingTap.shared.stop()
            if isRecording {
                hotkey.resume()
            }
        }
    }

    // MARK: - Languages

    private var languagesCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    languagesExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("Languages", systemImage: "globe")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(cycleSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Image(systemName: languagesExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if languagesExpanded {
                VStack(spacing: 0) {
                    ForEach(layouts, id: \.id) { layout in
                        HStack {
                            Text(layout.localizedName)
                                .font(.system(size: 11.5))
                            Spacer()
                            Toggle("", isOn: binding(for: layout.id))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                    }
                    Text("Checked languages participate in the hotkey cycle")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 13)
                        .padding(.bottom, 8)
                }
                .transition(.opacity)
            }
        }
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var cycleSummary: String {
        if languagesExpanded {
            return "\(enabledIDs.count) of \(layouts.count) in cycle"
        }
        let enabledNames = layouts.filter { enabledIDs.contains($0.id) }.map(\.localizedName)
        return enabledNames.isEmpty ? "none" : enabledNames.joined(separator: ", ")
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { enabledIDs.contains(id) },
            set: { isOn in
                if isOn {
                    enabledIDs.insert(id)
                } else {
                    enabledIDs.remove(id)
                }
                persist()
            }
        )
    }

    // MARK: - Hotkey

    private var hotkeyCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    hotkeyExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("Translate & switch", systemImage: "keyboard")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    hotkeyKeycaps(currentHotkey)
                    Image(systemName: hotkeyExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if hotkeyExpanded {
                hotkeyEditor
                    .transition(.opacity)
            }
        }
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var hotkeyEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isRecording {
                VStack(spacing: 6) {
                    Text("Press the new combination…")
                        .font(.system(size: 11.5, weight: .medium))
                    if liveSymbols.isEmpty {
                        Text("Hold modifiers, then press a key")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.tertiary)
                    } else {
                        HStack(spacing: 4) {
                            ForEach(Array(liveSymbols.enumerated()), id: \.offset) { _, symbol in
                                keycap(symbol)
                            }
                        }
                    }
                    if let recordingHint {
                        Text(recordingHint)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    Text("Esc to cancel")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            } else if let draft = draftHotkey {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        hotkeyKeycaps(draft)
                        Spacer()
                        switch draftStatus {
                        case .free:
                            statusPill("No known conflicts", color: .green)
                        case .occupied(let name):
                            statusPill("Occupied — \(name)", color: .red)
                        }
                    }
                    if case .occupied(let name) = draftStatus {
                        Text("Reserved for \(name) in macOS. Pick another combination.")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Button("Save shortcut") { saveDraft() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(draftStatus != .free)
                        Button("Discard") { draftHotkey = nil }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            } else {
                Text("Global — works in any app")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                Button("Record new shortcut") {
                    draftHotkey = nil
                    draftStatus = .free
                    isRecording = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var knownSystemShortcuts: [(config: HotkeyConfig, name: String)] {
        [
            (HotkeyConfig(keyCode: 49, modifiers: UInt32(cmdKey)), "Spotlight"),
            (HotkeyConfig(keyCode: 12, modifiers: UInt32(controlKey | cmdKey)), "Lock Screen"),
            (HotkeyConfig(keyCode: 20, modifiers: UInt32(shiftKey | cmdKey)), "Screenshot"),
            (HotkeyConfig(keyCode: 21, modifiers: UInt32(shiftKey | cmdKey)), "Screenshot selection")
        ]
    }

    private func startRecording() {
        recordingHint = nil
        HotkeyRecordingTap.shared.start(
            keyEvent: { keyCode, modifiers in
                handleCapturedKey(keyCode: keyCode, modifiers: modifiers)
            },
            modifiersChanged: { modifiers in
                liveSymbols = HotkeyConfig(keyCode: 0, modifiers: modifiers).modifierSymbols
            },
            escape: {
                cancelRecording()
            }
        )
    }

    private func stopRecording() {
        HotkeyRecordingTap.shared.stop()
        liveSymbols = []
        recordingHint = nil
    }

    private func handleCapturedKey(keyCode: UInt32, modifiers: UInt32) {
        // ⌘-only and ⇧-only combinations (⌘S, ⌘C, ⇧⌘3…) belong to app menus; as a
        // global hotkey they would shadow those actions everywhere. A global
        // shortcut must contain ⌥ or ⌃.
        guard modifiers & UInt32(optionKey | controlKey) != 0 else {
            recordingHint = "Add ⌥ or ⌃ — ⌘/⇧-only combinations are used by app shortcuts"
            return
        }
        draftHotkey = HotkeyConfig(keyCode: keyCode, modifiers: modifiers)
        recordingHint = nil
        evaluateDraft()
        isRecording = false
    }

    private func cancelRecording() {
        draftHotkey = nil
        draftStatus = .free
        recordingHint = nil
        isRecording = false
    }

    private func evaluateDraft() {
        guard let draft = draftHotkey else { return }
        if let known = knownSystemShortcuts.first(where: { $0.config == draft }) {
            draftStatus = .occupied(known.name)
            return
        }
        draftStatus = .free
    }

    private func saveDraft() {
        guard let draft = draftHotkey else { return }
        guard hotkey.rebind(to: draft) else {
            logError("could not register new hotkey combination")
            return
        }
        var settings = store.load()
        settings.hotkey = draft
        store.save(settings)
        currentHotkey = draft
        draftHotkey = nil
        draftStatus = .free
    }

    private func hotkeyKeycaps(_ config: HotkeyConfig) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(config.modifierSymbols.enumerated()), id: \.offset) { _, symbol in
                keycap(symbol)
            }
            keycap(config.keySymbol)
        }
    }

    // MARK: - Accessibility

    private var accessibilityCard: some View {
        HStack {
            Label("Accessibility", systemImage: "lock.shield")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            if status.granted {
                statusPill("Granted", color: .green)
            } else {
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    statusPill("Not granted — fix", color: .orange)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - Clipboard

    private var clipboardCard: some View {
        HStack {
            Label("Restore clipboard", systemImage: "clipboard")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Toggle("", isOn: $restoreClipboard)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .help("When on, the previous clipboard content is put back after fixing. Off keeps the translated text on the clipboard (recommended).")
        .onChange(of: restoreClipboard) { _ in persist() }
    }

    // MARK: - Launch at startup

    private var launchAtLoginCard: some View {
        HStack {
            Label("Launch at startup", systemImage: "power")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Toggle("", isOn: $launchAtLogin)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .help("Start Shift Happens automatically when you log in.")
        .onChange(of: launchAtLogin) { _, enabled in
            // SMAppService is the source of truth; on failure snap the toggle
            // back to the actual system state (e.g. bare `swift run` has no
            // bundle to register).
            do {
                try loginItem.setEnabled(enabled)
            } catch {
                launchAtLogin = loginItem.isEnabled
                logError("could not \(enabled ? "enable" : "disable") launch at startup: \(error)")
            }
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Shift Happens")
                    .font(.system(size: 12, weight: .semibold))
                Text("Version \(appVersion)")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    // MARK: - Shared

    private var cardColor: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    private func keycap(_ symbol: String) -> some View {
        Text(symbol)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 1.5)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }

    private func reload() {
        layouts = inputSource.enabledLayouts()
        let systemIDs = Set(layouts.map(\.id))
        let saved = store.load()
        let filtered = saved.enabledSourceIDs.filter { systemIDs.contains($0) }
        enabledIDs = filtered.isEmpty ? systemIDs : Set(filtered)
        restoreClipboard = saved.restoreClipboardAfterFix
        launchAtLogin = loginItem.isEnabled
    }

    private func persist() {
        var settings = store.load()
        settings.enabledSourceIDs = layouts.filter { enabledIDs.contains($0.id) }.map(\.id)
        settings.restoreClipboardAfterFix = restoreClipboard
        store.save(settings)
    }
}
