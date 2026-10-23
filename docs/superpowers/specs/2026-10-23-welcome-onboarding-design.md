# Shift Happens — First-Run Welcome & Live Accessibility Status

Date: 2026-10-23
Status: draft, pending review
Parent spec: `docs/superpowers/specs/2026-10-22-homebrew-tap-distribution-design.md` (post-install UX follow-up)

## Intent and why

Homebrew users hit two rough edges after install: the settings' Accessibility
pill stays "Not granted" even after granting (it is read once per `onAppear`),
and nothing at first launch tells the user they must grant Accessibility before
the app can do anything. A dedicated first-run welcome window with a live
status indicator fixes both.

## Goals / Non-goals

**Goals**

- Accessibility status in the UI is **live**: updates within ~1s of the user
  granting, in the welcome window and in Settings.
- First run (no Accessibility): a small welcome window explains why the
  permission is needed, offers a **Grant Accessibility** button that opens the
  system prompt directly (`AXIsProcessTrustedWithOptions`, prompt option), and
  enables **Get started** only once granted.
- Welcome shows once per state, not nagging: it appears on launch when
  Accessibility is missing; it never re-appears after a granted launch
  (detection = `AXIsProcessTrusted()` at `applicationDidFinishLaunching`).

**Non-goals**

- No onboarding for anything except Accessibility (hotkey/layout setup stays in
  Settings).
- No distributed-notification listening (no public API exists); polling while
  UI is visible only.

## Approach (chosen: dedicated welcome window)

- **`AccessibilityStatus`** (ShiftHappensCore, `@MainActor final class`,
  `ObservableObject`): `@Published private(set) var granted: Bool`; a
  `startPolling(every: 1s)` / `stopPolling()` pair using `Timer`; `refresh()`
  re-reads `AXIsProcessTrusted()`. Unit-testable: polling logic injected via a
  `now`-style closure? No — inject a `check: () -> Bool` closure (defaults to
  `AXIsProcessTrusted`), tests drive fake checks and count timer ticks.
- **`WelcomeView`** (ShiftHappens/UI), approved visual direction **B′**: app icon
  + "Shift Happens" header; a two-step checklist:
  1. **Grant Accessibility** → `AXIsProcessTrustedWithOptions` (system prompt),
     live status pill;
  2. **Try it right here** — a sandbox box with the string **"shift happens"
     rendered in the user's other layout** (generated live via
     `KeymapTranslator.translate` from the active layout's keymap into the next
     enabled layout's keymap — the exact inverse of the app's fix path, so the
     demo text genuinely fixes itself when selected + hotkey). Before
     Accessibility is granted the sandbox is static illustration. When the
     sandbox text becomes the correct string, step 2 checks off.
  **Get started** enables once Accessibility is granted (step 2 completion is
  bonus feedback, not a gate — nobody gets stuck); closing the window stops
  polling. Fallback when the wrong-layout string is not generable (layouts
  unusable or <2 layouts): hide step 2, show only step 1.
- **`AppDelegate.applicationDidFinishLaunching`**: create one
  `AccessibilityStatus`, pass it to both the welcome window and MenuController
  → SettingsView (which drops its own `AXIsProcessTrusted()` read and starts
  polling while visible instead). If `!granted` at launch → show the welcome
  window (key window, `.canBecomeKey` — note: LSUIElement app windows need an
  explicit `NSWindow` subclass or `NSPanel` that can become key).
- SettingsView's card keeps its "open System Settings" fallback button.

## Left to the builder

- Exact SwiftUI composition and copy of the welcome window
- Where the polling timer lives (window-scoped vs shared) — must stop when no
  UI needs it
- Test shape for the timer (may use shorter interval injection)

## Acceptance

1. Fresh state (Accessibility not granted): app launch → welcome window appears
   with explanation; Get started disabled.
2. Clicking Grant Accessibility opens the system prompt; after approving, the
   pill flips to Granted within ~1s without reopening anything.
3. Get started enables; clicking it closes the window; app works (⌥⌘K fixes
   text).
4. Next launch (granted): no welcome window.
5. Settings window: pill now live-updates there too.
6. `swift test` green, including new AccessibilityStatus tests.
