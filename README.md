# Shift Happens

Because it does. A macOS menu bar utility that fixes text typed in the wrong keyboard layout.

Typed Ukrainian words while the English layout was active — got `ghbdtn` instead of `привет`? Select the text, press ⌥⌘K: the input source switches and the selected text is remapped key-by-key to the other language.

## Status

**Working prototype (increment 1 complete).** See [docs/concept.md](docs/concept.md) for the product idea and [docs/superpowers/specs/2026-09-08-keyboard-switcher-design.md](docs/superpowers/specs/2026-09-08-keyboard-switcher-design.md) for the increment 1 design.

## Features

- Global hotkey: switch layout + "translate" the selected text between layouts
- Menu bar item with Settings / About / Quit
- Language setup in settings, or taken from system input sources
- Support for more than two input sources (hotkey cycles through them)

## Development workflow

Development is spec-driven and AI-agent-friendly. Non-trivial features go through
**idea → brainstorm → written spec → spec review → plan → TDD implementation →
verification**. Agent instructions live in [AGENTS.md](AGENTS.md); technical
quirks in [CLAUDE.md](CLAUDE.md). Notable changes are recorded in
[CHANGELOG.md](CHANGELOG.md); architectural decisions in [docs/adr/](docs/adr/).

## Documentation

| What | Where |
|---|---|
| Product concept (source of truth) | [docs/concept.md](docs/concept.md) |
| Design specs | `docs/superpowers/specs/` |
| Implementation plans | `docs/superpowers/plans/` |
| Architectural decision records | [docs/adr/](docs/adr/) |
| Changelog | [CHANGELOG.md](CHANGELOG.md) |

## Install

Via [Homebrew](https://brew.sh) (Apple Silicon, macOS 14+):

```bash
brew tap travmik/tap https://github.com/travmik/homebrew-tap
brew install --cask travmik/tap/shift-happens
```

After installing (and again after every `brew upgrade`):

1. **Allow the app in Gatekeeper** — the first launch from Finder is blocked
   ("Apple cannot check it for malicious software") because the app is
   unsigned. Open **System Settings → Privacy & Security** and click
   **"Open Anyway"**, or run
   `xattr -d com.apple.quarantine /Applications/ShiftHappens.app`.
2. **Grant Accessibility permission**: System Settings → Privacy & Security →
   Accessibility → ShiftHappens.app.

Both steps repeat after each update — the app is unsigned by design, so macOS
ties the approval and the permission to the exact build. See
[ADR 0002](docs/adr/0002-unsigned-tap-distribution.md) for the reasoning and
the notarization path that would remove this friction.

### Releasing

The release pipeline is fully automated: push a version tag and GitHub Actions
builds the app, publishes a GitHub Release, and updates the Homebrew tap:

```bash
git tag v0.2.0 && git push origin v0.2.0
```

## Build

Swift 5.9, macOS 14+ (arm64), SwiftPM:

```bash
swift build            # debug build
swift test             # unit tests
swift run              # run from CLI for development
./scripts/make-app.sh  # assemble build/ShiftHappens.app for daily use
```

The app requires **Accessibility** permission (System Settings → Privacy & Security →
Accessibility) to read and replace selected text. Grant it to `ShiftHappens.app`
(or to your terminal app when running via `swift run`).

## License

[MIT](LICENSE)
