# Changelog

All notable changes to **Shift Happens** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Project documentation for spec-driven development: `AGENTS.md` (agent
  instructions), architecture decision records (`docs/adr/`), and this
  changelog.

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

[Unreleased]: https://github.com/travmik/shift-happens/compare/2cf62f9...HEAD
[0.1.0]: https://github.com/travmik/shift-happens/tree/2cf62f9808b731ffb29ba2f0ac1e10f477e40236
