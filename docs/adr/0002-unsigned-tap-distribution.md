# 0002. Unsigned Homebrew tap distribution

Date: 2026-10-22
Status: Accepted

## Context

Shift Happens should be installable with one command. The build currently signs
with the self-signed `keyboard-switcher-dev` identity — but that identity exists
only in the maintainer's keychain, so CI cannot reproduce it. We have no Apple
Developer account. Two constraints shape the options:

- Homebrew quarantines cask downloads by default, and macOS 15 Sequoia made
  Gatekeeper much harder on unnotarized apps (the old right-click-Open bypass
  is gone; users must go through System Settings → Open Anyway).
- The Accessibility (TCC) grant is tied to the app's code signature: an ad-hoc
  signature changes with every rebuild, so each update re-prompts for
  Accessibility.

## Decision

1. Release builds are **ad-hoc signed** (`KS_SIGN_IDENTITY=-`); no Developer ID,
   no notarization. Distribution is a **personal tap** (`travmik/homebrew-tap`)
   with cask `shift-happens`.
2. The release artifact is a **`.tar.gz`**, not `.zip` or `.dmg`: tar does not
   carry the quarantine xattr, so cask installs never trigger Gatekeeper.
3. The **Accessibility grant is granted manually by the user** after install
   (the app already handles the not-granted state) and re-granted after each
   update. This is documented in the README, the cask `caveats`, and ADR 0002.
4. The `keyboard-switcher-dev` identity remains the **local dev** default in
   `scripts/make-app.sh` — it keeps the maintainer's own grant stable across
   local rebuilds. This scopes the earlier "never go ad-hoc" rule (CLAUDE.md /
   AGENTS.md) to local development builds only.
5. Releases are fully automated: tag `vX.Y.Z` → GitHub Actions builds, creates
   the GitHub Release, and updates the tap cask (version, sha256, url).

## Alternatives considered

- **Apple Developer ID + notarization ($99/yr)** — the long-term gold standard:
  no re-grants, no Gatekeeper concerns at all. Rejected for now (no account);
  revisit if distribution grows. The tar.gz choice does not block adopting it.
- **`.zip` artifact** — conventional for GUI apps, but carries the quarantine
  xattr: every install would hit the Sequoia Gatekeeper maze. Rejected.
- **Official `homebrew/cask` repo** — requires notability and a review process;
  a personal tap has no gate and can be migrated later.

## Consequences

- Users re-grant Accessibility after every `brew upgrade` — the one piece of
  post-install friction; documented everywhere it can be seen in advance.
- Releases need no signing secrets at all; CI holds only the tap-push PAT
  (`HOMEBREW_TAP_TOKEN`).
- Local dev builds stay signed with `keyboard-switcher-dev`; the signing quirk
  in CLAUDE.md/AGENTS.md applies to local builds only.
