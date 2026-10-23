# AGENTS.md — Instructions for AI Agents

Persistent guidance for any AI agent working in this repository. For deep technical
details and hard-won runtime quirks, also read [CLAUDE.md](CLAUDE.md) — everything
there applies to you too.

## What this is

**Shift Happens** — a macOS menu bar utility that fixes text typed in the wrong
keyboard layout. [docs/concept.md](docs/concept.md) is the **source of truth for
product intent**. If implementation questions arise about behavior, resolve them
against that file.

Stack: Swift 5.9, SwiftUI + AppKit, macOS 14+ (arm64), SwiftPM, no third-party
dependencies. App is packaged via `scripts/make-app.sh` — do not add an Xcode
project unless explicitly asked.

## Development methodology (spec-driven)

Follow this sequence for any non-trivial feature or change:

1. **Describe** — start from a free-form description of the idea and the problem
   it solves.
2. **Brainstorm** — use the Superpowers `brainstorming` skill: clarify
   requirements, explore alternatives, identify risks, discuss architectural
   decisions. The resulting design spec goes to
   `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
3. **Review the spec** — the user reviews and approves the written spec
   **before any implementation code is written**.
4. **Plan** — use the Superpowers `writing-plans` skill. Plans consist of small,
   independently verifiable tasks and go to
   `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`.
5. **Implement with TDD** — use the `test-driven-development` skill: write the
   failing test first, then the implementation. Keymap translation logic lives in
   pure, testable functions with no AppKit dependencies and must be covered by
   unit tests.
6. **Verify before claiming done** — use the `verification-before-completion`
   skill: run the actual commands and confirm their output before saying work
   is complete. Review the diff before committing.

Do not skip the review gates (steps 3 and 5's plan review) without the user's
explicit go-ahead.

## Documentation map

| What | Where |
|---|---|
| Product concept (source of truth) | `docs/concept.md` |
| Design specs (one per feature/increment) | `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` |
| Implementation plans | `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` |
| Architectural decision records | `docs/adr/NNNN-title.md` (see `docs/adr/README.md`) |
| Changelog | `CHANGELOG.md` (Keep a Changelog format) |
| Agent instructions | `AGENTS.md` (this file), `CLAUDE.md` (technical quirks) |

Update the changelog and, when a decision was made, the relevant ADR as part of
the change — documentation is not a follow-up task.

## Architectural decision records

Write an ADR (`docs/adr/`) when you choose between real alternatives and the
choice affects structure, APIs, dependencies, permissions, or system
interactions. One ADR per decision; accepted ADRs are immutable — supersede
them with a new one rather than editing.

## Git conventions

- Conventional Commits: `feat:`, `fix:`, `docs:`, `build:`, `test:`, `refactor:`, `chore:`
- Commits are authored **only** by the repo owner (Stas <travmik@gmail.com>).
  **No bot attribution** — never add `Co-authored-by:` trailers or similar.
- Commit messages: imperative mood, lowercase summary line, optional body explaining *why*.

## Commands

```bash
swift build           # debug build
swift test            # unit tests (XCTest, Tests/ShiftHappensTests)
swift run             # run the menubar app from CLI
./scripts/make-app.sh # assemble build/ShiftHappens.app (ad-hoc signed app bundle)
```

There is no formatter or linter installed for this toolchain — match the style
of the surrounding code. Always run `swift test` before claiming work is done.

## Runtime permissions and quirks (do not rediscover the hard way)

- The AX API requires the **Accessibility** permission; handle the "not granted" state.
- **Never write the selection via AX** — replacement pastes (single writer); AX is read-only here.
- ChatGPT ignores all synthetic key events — replace via its Edit→Paste menu item (`AXUIElementPerformAction`).
- Synthetic keystrokes must be posted as a full physical stream (⌘ flagsChanged down, key down, key up, ⌘ flagsChanged up).
- `scripts/make-app.sh` signs local builds with the stable `keyboard-switcher-dev` identity — never go back to ad-hoc `--sign -` **for local dev builds**, it invalidates the Accessibility grant. Release builds (CI) are ad-hoc by design — see [ADR 0002](docs/adr/0002-unsigned-tap-distribution.md), including the empirical Gatekeeper note.

See [CLAUDE.md](CLAUDE.md) for the full rationale behind each quirk.

## Hygiene

- **Never store API keys, tokens, or secrets in the repository.** If you find
  one, flag it — do not copy it into docs, settings, or commits.
- Do not add extensions, MCP servers, or other infrastructure unless they give
  a concrete, articulable benefit.
- Superpowers skills are available (brainstorming, writing-plans,
  test-driven-development, systematic-debugging, verification-before-completion,
  …). Use them; do not recreate or duplicate them.
