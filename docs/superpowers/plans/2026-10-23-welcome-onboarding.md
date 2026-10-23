# Welcome Onboarding & Live Accessibility Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** First-run welcome window (B′: header, grant step, self-demo sandbox) with live Accessibility status shared by the welcome window and Settings.

**Architecture:** One observable (`AccessibilityStatus`) polls `AXIsProcessTrusted()` while any UI is visible; a pure `SandboxDemoText` helper generates the wrong-layout demo string via the existing `KeymapTranslator`; `WelcomeView` in a key-capable `NSPanel` is shown at launch only when not granted; Settings consumes the same status.

**Tech Stack:** Swift 5.9, SwiftUI + AppKit, XCTest, Carbon AX APIs.

**Spec:** `docs/superpowers/specs/2026-10-23-welcome-onboarding-design.md`

## Global Constraints

- No private APIs; polling only (`AXIsProcessTrusted()`), no distributed notifications.
- Polling must stop when the window that needs it closes.
- Demo string format: `KeymapTranslator.translate(text, source: activeLayoutKeymap, target: nextEnabledLayoutKeymap)` — never hand-written gibberish.
- Get started is gated **only** on Accessibility granted; the sandbox completing step 2 is feedback, not a gate.
- Welcome window appears at launch only when `!AXIsProcessTrusted()`; never after a granted launch.
- Conventional commits, author Stas, no bot attribution; `swift test` green before done.

## Review Focus

- Polling leak: timer must invalidate when window closes — verified by test and by window teardown path.
- Sandbox with unusable layouts (<2 keymappable layouts, or translation returns input unchanged): step 2 hidden, not a broken demo.
- Get started never permanently disabled: always enabled once granted even if sandbox never completes.
- Settings pill must live-update (the original bug): verified by polling, not onAppear.
- Welcome must not reappear after a granted launch (state read at launch, not stored flag).

---

### Task 1: `AccessibilityStatus` (ShiftHappensCore, TDD)

**Files:**
- Create: `Sources/ShiftHappensCore/Services/AccessibilityStatus.swift`
- Test: `Tests/ShiftHappensTests/AccessibilityStatusTests.swift`

**Interfaces:**
- Produces: `@MainActor public final class AccessibilityStatus: ObservableObject` — `@Published private(set) var granted: Bool`; `init(check: @escaping () -> Bool = { AXIsProcessTrusted() }, interval: TimeInterval = 1.0)`; `func startPolling()` / `func stopPolling()` / `func refresh()`. WelcomeView and SettingsView both observe it.

- [ ] **Step 1: Write failing tests** — (a) initial value = check(); (b) `refresh()` updates when injected check changes; (c) `startPolling` with `interval: 0.02` flips `granted` within ~0.2s using XCTestExpectation; (d) `stopPolling` freezes updates (change check after stop, wait, no change).
- [ ] **Step 2: Run, verify FAIL** — `swift test --filter AccessibilityStatusTests`
- [ ] **Step 3: Implement** — `Timer.publish`-free plain `Timer.scheduledTimer` on main; invalidate in `stopPolling` and `deinit`.
- [ ] **Step 4: Run, verify PASS** — `swift test --filter AccessibilityStatusTests`
- [ ] **Step 5: Commit** — `feat: accessibility status with injectable check and polling`

### Task 2: `SandboxDemoText` (ShiftHappensCore, TDD)

**Files:**
- Create: `Sources/ShiftHappensCore/Keymap/SandboxDemoText.swift`
- Test: `Tests/ShiftHappensTests/SandboxDemoTextTests.swift`

**Interfaces:**
- Consumes: `KeymapTranslator`, `Keymap` (existing).
- Produces: `public enum SandboxDemoText` — `static func generate(text: String, active: Keymap?, next: Keymap?) -> String?` returning `translate(text, source: active!, target: next!)` or `nil` when either keymap is nil or result == input (translation is a no-op → unusable layouts). Called by WelcomeView with the active layout's keymap and the next enabled layout's keymap.

- [ ] **Step 1: Write failing tests** — with two fake `Keymap`s (latin ↔ cyrillic mapping over shared keycodes): returns the remapped string; nil when active nil; nil when next nil; nil when result == input.
- [ ] **Step 2: Run, verify FAIL** — `swift test --filter SandboxDemoTextTests`
- [ ] **Step 3: Implement** — thin wrapper around `KeymapTranslator.translate` with the guards.
- [ ] **Step 4: Run, verify PASS** — `swift test --filter SandboxDemoTextTests`
- [ ] **Step 5: Commit** — `feat: sandbox demo text generator via KeymapTranslator`

### Task 3: `WelcomeView` + window (ShiftHappens/UI)

**Files:**
- Create: `Sources/ShiftHappens/UI/WelcomeView.swift`
- Modify: `Sources/ShiftHappens/KeyboardSwitcherApp.swift` (AppDelegate: create shared `AccessibilityStatus`, show welcome at launch when not granted)

**Interfaces:**
- Consumes: `AccessibilityStatus` (Task 1), `SandboxDemoText` (Task 2), `InputSourceService`, `KeymapProvider`, `SettingsStore`.
- Produces: `AppDelegate.showWelcomeIfNeeded()` called at end of `applicationDidFinishLaunching`; welcome window keeps polling until closed; window is key-capable (NSPanel/NSWindow subclass overriding `canBecomeKey`), non-activating style consistent with LSUIElement app.

- [ ] **Step 1: Implement `WelcomeView`** — header (icon + name), step 1 (Grant button → `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true] as CFDictionary, ...)`, pill bound to `AccessibilityStatus.granted`), step 2 sandbox (`TextEditor`/`TextField` prefilled with `SandboxDemoText.generate("shift happens", ...)` resolved from current + next enabled layout keymaps; step auto-checks when edited text == "shift happens"; step hidden when generation returned nil), **Get started** disabled until `granted`, `onDisappear` → `status.stopPolling()`, window close → same.
- [ ] **Step 2: Wire AppDelegate** — shared `AccessibilityStatus`; `showWelcomeIfNeeded()` presents the panel ordered front if `!granted` at launch; `MenuController`/`SettingsView` receive the same status object.
- [ ] **Step 3: Verify manually** — `swift run`: fresh state (toggle Accessibility off for the app in System Settings if previously granted) → welcome appears; Grant → system prompt → pill flips ~1s; sandbox fixes itself on ⌥⌘K → step 2 checks; Get started closes window; relaunch → no welcome.
- [ ] **Step 4: Commit** — `feat: first-run welcome window with grant step and self-demo sandbox`

### Task 4: Live status in Settings (fixes the stale pill)

**Files:**
- Modify: `Sources/ShiftHappens/UI/SettingsView.swift`

**Interfaces:**
- Consumes: shared `AccessibilityStatus` passed from MenuController.
- Produces: `accessibilityCard` binds to `status.granted`; `reload()` no longer sets `accessibilityGranted`; polling runs while settings visible (`onAppear` start, `onDisappear` stop).

- [ ] **Step 1: Swap the one-shot read for the shared observable** (keep the "open System Settings" fallback button).
- [ ] **Step 2: Verify manually** — open Settings while not granted → grant → pill flips to Granted within ~1s without closing the window.
- [ ] **Step 3: Run full suite** — `swift test` (all green, including Task 1–2 tests)
- [ ] **Step 4: Commit** — `fix: settings accessibility pill live-updates via shared status`

### Task 5: Docs

**Files:**
- Modify: `CHANGELOG.md` (Unreleased → Added: first-run welcome with self-demo sandbox, live accessibility status)
- Modify: `docs/superpowers/specs/2026-10-23-welcome-onboarding-design.md` (Status → implemented)

- [ ] **Step 1: Update both files**
- [ ] **Step 2: Commit** — `docs: welcome onboarding implemented — changelog and spec status`
