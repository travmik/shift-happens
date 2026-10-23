# Shift Happens — Homebrew Distribution via Personal Tap

Date: 2026-10-22
Status: implemented (v0.1.0, v0.1.1)
Source of truth for product intent: `docs/concept.md`

## 1. Intent and why

Any user should be able to install Shift Happens with one command:

```bash
brew install --cask travmik/tap/shift-happens
```

We start with a personal Homebrew tap (`travmik/homebrew-tap`) rather than the
official `homebrew/cask` repo — no notability requirements, full control, and
an upgrade path to the official repo later. Releases are fully automated:
tagging this repo builds the app on CI, publishes a GitHub Release, and updates
the tap cask in the same run.

## 2. Goals / Non-goals / Anti-goals

**Goals**

- One-command install and uninstall via Homebrew cask from our tap
- Fully automated release pipeline: `git tag vX.Y.Z && git push --tags` is the
  entire release procedure
- Reproducible builds that do not depend on the maintainer's laptop or keychain
- Honest handling of the Accessibility permission requirement

**Non-goals (this increment)**

- Official `homebrew/cask` submission
- Apple Developer ID signing and notarization ($99/yr)
- Intel (x86_64) builds — the app targets macOS 14+ arm64
- Auto-update inside the app (Sparkle or similar) — `brew upgrade` is the
  update path
- Supporting `brew install` (formula) — this is a cask, the artifact is an .app

**Anti-goals (would make this a failure)**

- Users getting Gatekeeper popups or running `xattr -d` commands manually
- Releases requiring manual cask edits (stale sha256 → checksum errors on
  `brew upgrade`)
- Storing any token or secret inside this repository

## 3. Decisions made during brainstorming

| Decision | Choice | Rationale |
|---|---|---|
| Distribution channel | Personal tap first | No notability bar; official cask repo later if the project grows |
| Signing | Ad-hoc (`--sign -`) for release builds | No Apple Developer account; see 5.1 for how we avoid Gatekeeper despite Homebrew's default quarantine |
| Artifact | `.tar.gz` (not `.zip`, not `.dmg`) | Homebrew quarantines cask downloads by default, and macOS 15 Sequoia makes Gatekeeper hard on unnotarized apps — but tar archives don't carry the quarantine xattr, so a tar.gz artifact never triggers Gatekeeper |
| Accessibility permission | User grants manually; documented in README and cask `desc` | App already implements the "not granted" state |
| Release automation | CI builds, releases, **and pushes the tap update** (approach A) | Removes the only manual step; stale-cask checksum errors are the failure mode we're avoiding |
| Architecture | arm64-only cask (`arch: :arm64`) | Matches the app's target; Intel users get a clean "unsupported" message |
| Versioning | Git tags `vX.Y.Z`; first release **v0.1.0** | Matches the existing CHANGELOG entry |

## 4. Constraints

- CI never holds the dev signing identity; release builds are ad-hoc. The
  `keyboard-switcher-dev` identity remains the **local** default in
  `make-app.sh` (it keeps the developer's own Accessibility grant stable across
  local rebuilds) — release builds override it via environment.
- Secrets live only in GitHub Actions secrets. The tap push token is a
  fine-grained PAT scoped to `travmik/homebrew-tap` with `contents: write` and
  nothing else.
- Keep a Changelog / SemVer conventions already in place apply to releases.

## 5. How it works (the parts we decided)

### 5.1 Build script changes (`scripts/make-app.sh`)

- `SIGN_IDENTITY` becomes an environment variable with the current
  `keyboard-switcher-dev` as default. CI sets `SIGN_IDENTITY=-` (ad-hoc).
- Tar artifact created with
  `tar --exclude '.DS_Store' -czf ShiftHappens-vX.Y.Z-arm64.tar.gz -C build ShiftHappens.app`
  — tar does not store the quarantine xattr, which is the whole point of the
  format choice (see the decisions table). The ad-hoc code signature itself is
  carried inside the bundle and survives fine.
- The script (or a sibling `scripts/make-release-artifact.sh`) takes the version
  from the tag and outputs the final artifact name and sha256.

### 5.2 CI workflow (`.github/workflows/release.yml`)

Trigger: push of a tag matching `v*`. Runner: `macos-14` (arm64, Swift 5.9
available). Steps:

1. Checkout; `swift build -c release`
2. `make-app.sh` with `SIGN_IDENTITY=-`, version from the tag
3. `tar czf` the app → compute `sha256`
4. Create GitHub Release for the tag; attach the tar.gz (release notes generated
   from commits since the previous tag)
5. Tap update: clone `travmik/homebrew-tap` with the token, rewrite the cask
   (`version`, `sha256`, `url`) — a small Ruby script editing the cask file,
   not regex-guessing in shell — commit as
   `shift-happens vX.Y.Z`, push

### 5.3 The tap (`travmik/homebrew-tap`)

- New public repo containing `Casks/shift-happens.rb` (scaffolded once, by
  hand or by CI on first run).
- Cask shape (final wording is the builder's call):

```ruby
cask "shift-happens" do
  version "0.1.0"
  sha256 arm64: "…"

  url "https://github.com/travmik/shift-happens/releases/download/v#{version}/ShiftHappens-v#{version}-arm64.tar.gz"
  name "Shift Happens"
  desc "Menu bar utility that fixes text typed in the wrong keyboard layout"
  homepage "https://github.com/travmik/shift-happens"

  app "ShiftHappens.app"

  caveats <<~EOS
    Grant Accessibility permission after installing:
    System Settings → Privacy & Security → Accessibility → ShiftHappens.app.
    Re-grant after each update: the app is unsigned, so macOS ties the
    permission to the exact build.
  EOS
end
```

- Livecheck friendly: `url` strategy picks up new GitHub releases automatically.

### 5.4 Secrets

| Secret | Scope | Used by |
|---|---|---|
| `HOMEBREW_TAP_TOKEN` | fine-grained PAT, `contents: write` on `travmik/homebrew-tap` only | tap-update step |

Created once by the maintainer in GitHub repo settings; never appears in the
repo.

### 5.5 Documentation updates (part of the same work)

- **ADR 0002** (`docs/adr/`): unsigned tap distribution — records the signing
  decision and its Accessibility re-grant consequence, and notes that the
  CLAUDE.md/AGENTS.md "never ad-hoc" rule applies to *local dev* builds, not
  release builds.
- **README**: Install section (`brew tap` + `brew install --cask`), the
  Accessibility caveat, and the release procedure ("tag and push").
- **CHANGELOG**: note distribution availability under `Unreleased`.
- **AGENTS.md / CLAUDE.md**: adjust the signing quirk wording (see ADR 0002).

## 6. What is left to the builder

- Exact CI syntax, runner image pinning, and action versions
- The Ruby cask-editing implementation and its tests-by-inspection
- Whether the tap scaffold is created manually once or by the first CI run
- Release-notes formatting details
- Cask wording polish (must keep the Accessibility caveat substance)

## 7. First release checklist (acceptance)

1. Tag `v0.1.0` → CI produces a GitHub Release with the arm64 tar.gz
2. Tap cask updated automatically; `brew install --cask travmik/tap/shift-happens`
   installs the app into /Applications with **no Gatekeeper prompt** (tar.gz
   carries no quarantine xattr)
3. App launches, shows the Accessibility "not granted" state, works after the
   user grants it
4. Bump-tag a test version → `brew upgrade` installs it (accepting the
   expected re-grant of Accessibility)
5. `brew uninstall --cask shift-happens` removes the app cleanly
