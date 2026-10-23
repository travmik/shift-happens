# Changelog

All notable changes to **Shift Happens** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] — First-run onboarding

### Added

- First-run welcome window: explains why Accessibility is needed, offers the
  system grant prompt, and includes a self-demo sandbox — "shift happens"
  rendered in the user's other layout (the input source is switched for the
  demo and restored when the window closes), which the app fixes in place when
  selected + hotkey. Get started unlocks once Accessibility is granted.
- Live Accessibility status: the settings pill (and welcome window) now update
  within a second of granting instead of requiring a window reopen.

## [0.2.0] — Documentation

Documentation-only release: project setup for spec-driven development
(`AGENTS.md`, ADRs, changelog), Homebrew install instructions, and the
ADR 0002-documented unsigned distribution decision.

## [0.1.0] — Increment 1

Initial working prototype of the core concept.

### Added

- Global hotkey (⌥⌘K): capture the selected text, remap it key-by-key between
  the two layouts, replace it, and switch the input source
- Keymap extraction from system layouts via `UCKeyTranslate`, including the
  shift layer (capitals)
- Input source enumeration, ordering, and switching via TIS; with more than two
  input sources the hotkey cycles through the enabled languages
- Menu bar UI (keyboard icon) with Settings and About windows; carded settings
  with a recordable hotkey and launch-at-login option
- Settings persistence in `UserDefaults`
- App bundle packaging via `scripts/make-app.sh`, signed with the stable
  self-signed `keyboard-switcher-dev` identity
- Design spec and implementation plan for increment 1
  (`docs/superpowers/specs/`, `docs/superpowers/plans/`)

### Fixed

- Text replacement uses pasting as the single writer (AX writes caused
  duplication races, e.g. in Telegram)
- Three-tier replacement: verified AX write → physical-stream paste →
  Edit→Paste menu press (needed for ChatGPT, which ignores synthetic key events)
- Selection reading falls back to the clipboard when AX read fails (Electron apps)
- Optional clipboard restore after paste (off by default) for slow-paste apps

[Unreleased]: https://github.com/travmik/shift-happens/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/travmik/shift-happens/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/travmik/shift-happens/compare/v0.1.1...v0.2.0
[0.1.0]: https://github.com/travmik/shift-happens/tree/2cf62f9808b731ffb29ba2f0ac1e10f477e40236
