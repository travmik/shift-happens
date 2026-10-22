# Homebrew Tap Distribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `brew install --cask travmik/tap/shift-happens` works, and pushing a `vX.Y.Z` tag builds, releases, and updates the tap automatically.

**Architecture:** `make-app.sh` gains version injection; a new `make-release-artifact.sh` produces a quarantine-free tar.gz + sha256; a tested Ruby script rewrites the tap cask; a GitHub Actions workflow ties it together on tag push; docs record the decision. No app (Swift) code changes.

**Tech Stack:** Bash scripts, Ruby 2.6 stdlib (minitest for tests), GitHub Actions (`macos-14`), `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-10-22-homebrew-tap-distribution-design.md`

## Global Constraints

- Release builds are ad-hoc: CI sets `KS_SIGN_IDENTITY=-`; local default stays `keyboard-switcher-dev` (see `scripts/make-app.sh`).
- Artifact name format, verbatim: `ShiftHappens-v<version>-arm64.tar.gz` (e.g. `ShiftHappens-v0.1.0-arm64.tar.gz`), version = git tag minus leading `v`.
- Tarball contains `ShiftHappens.app` at its root and no `.DS_Store`.
- Cask token: `shift-happens`; app path in cask: `app "ShiftHappens.app"`; `arch: :arm64` via `sha256 arm64:` + explicit `arch arm64:` stanzas.
- No secrets in this repository; the only secret is `HOMEBREW_TAP_TOKEN` (fine-grained PAT, `contents: write` on `travmik/homebrew-tap` only), set in GitHub Actions secrets.
- Tap commit message: `shift-happens vX.Y.Z`.
- Conventional commits in this repo; no bot attribution (commits authored by Stas).

## Review Focus

- Tag with prerelease suffix (`v0.1.0-rc1`): version stripping must keep the suffix in version and filename, never mangle them. → pinned by Task 2 test steps.
- Artifact script re-run with the same version: must overwrite the old tarball, not accumulate stale output. → pinned by Task 2 test steps.
- Ruby updater against a malformed/unexpected cask file: must fail loudly rather than silently write a broken cask. → pinned by Task 3 minitest cases.
- CI without `HOMEBREW_TAP_TOKEN` (e.g. fork PR): must fail with a clear message before touching git, not push an empty commit. → pinned by Task 4 workflow structure.
- Tarball accidentally containing `.DS_Store` or nested paths: excluded/verified. → pinned by Task 2 test steps.

---

### Task 1: Version injection in `make-app.sh`

**Files:**
- Modify: `scripts/make-app.sh` (Info.plist heredoc, version lines)

**Interfaces:**
- Consumes: nothing new
- Produces: `KS_APP_VERSION` env var (default `0.1.0`); `CFBundleShortVersionString` = `$KS_APP_VERSION`, `CFBundleVersion` = build number `1`. Task 2's script calls this script with `KS_APP_VERSION` set.

- [ ] **Step 1: Set the two plist keys from the env var**

```bash
KS_APP_VERSION="${KS_APP_VERSION:-0.1.0}"
```
and in the heredoc:
```xml
<key>CFBundleShortVersionString</key><string>${KS_APP_VERSION}</string>
```

- [ ] **Step 2: Verify**

Run: `KS_APP_VERSION=9.9.9 ./scripts/make-app.sh && /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/ShiftHappens.app/Contents/Info.plist`
Expected: `9.9.9`

Run: `codesign -dv build/ShiftHappens.app 2>&1 | grep -c 'keyboard-switcher-dev'`
Expected: `1` (local default identity unchanged)

- [ ] **Step 3: Commit**

```bash
git add scripts/make-app.sh
git commit -m "build: inject app version into bundle via KS_APP_VERSION"
```

### Task 2: Release artifact script `scripts/make-release-artifact.sh`

**Files:**
- Create: `scripts/make-release-artifact.sh` (executable)

**Interfaces:**
- Consumes: `scripts/make-app.sh` (Task 1)
- Produces: `scripts/make-release-artifact.sh <git-tag>`; artifacts `build/ShiftHappens-v<version>-arm64.tar.gz`; stdout lines `artifact=build/<name>` and `sha256=<hash>` — Task 4's workflow parses these.

- [ ] **Step 1: Write the script**

Logic (bash, `set -euo pipefail`):
1. Arg = git tag (e.g. `v0.1.0-rc1`); `version="${1#v}"` (keeps suffix intact)
2. Reject if version contains characters outside `[A-Za-z0-9.+-]` (fail fast on a bad tag)
3. `KS_SIGN_IDENTITY=- KS_APP_VERSION="$version" ./scripts/make-app.sh`
4. `tar --exclude '.DS_Store' -czf "build/ShiftHappens-v${version}-arm64.tar.gz" -C build ShiftHappens.app`
5. `shasum -a 256` the tarball; echo `artifact=` and `sha256=` lines

- [ ] **Step 2: Verify — happy path**

Run: `./scripts/make-release-artifact.sh v0.1.0`
Expected: `build/ShiftHappens-v0.1.0-arm64.tar.gz` exists; stdout has both `artifact=` and `sha256=` lines (64 hex chars)

- [ ] **Step 3: Verify — the Review Focus cases**

- Extract to a temp dir: `ShiftHappens.app` at root; `xattr -l` on the extracted app shows **no** `com.apple.quarantine`; `codesign -dv` on it reports `Signature=adhoc`
- `tar tzf` output contains no `.DS_Store`
- Re-run the script: same tarball path, still valid (`tar tzf` succeeds)
- `./scripts/make-release-artifact.sh 'v0.1.0$(rm -rf /)'` fails with a clear error, creates nothing

- [ ] **Step 4: Commit**

```bash
git add scripts/make-release-artifact.sh
git commit -m "build: release artifact script — ad-hoc signed tar.gz with sha256"
```

### Task 3: Tap cask updater `scripts/update-homebrew-cask.rb` (TDD)

**Files:**
- Create: `scripts/update-homebrew-cask.rb`
- Test: `scripts/update-homebrew-cask-test.rb`

**Interfaces:**
- Consumes: nothing
- Produces: `ruby scripts/update-homebrew-cask.rb <cask-path> <version> <sha256> <repo-slug>`. Creates the cask from a built-in template if the file (or its directory) is missing; otherwise rewrites `version`, `sha256 arm64:`, and the `url` line in the existing cask. Fails (exit 1, stderr message) if the file exists but doesn't look like our cask (no `cask "shift-happens"` line). Task 4 calls it with cask path `Casks/shift-happens.rb` and repo slug `travmik/shift-happens`.

- [ ] **Step 1: Write the failing minitest suite**

`scripts/update-homebrew-cask-test.rb` (plain `minitest/autorun`, run with system Ruby 2.6 — no gems):
- `test_creates_cask_when_missing`: tmpdir path; run the script; result contains `cask "shift-happens"`, `version "0.1.0"`, the given sha256, `url ".../releases/download/v0.1.0/ShiftHappens-v0.1.0-arm64.tar.gz"`, `app "ShiftHappens.app"`, the Accessibility caveat text
- `test_updates_existing_cask`: fixture cask (copy of the template with version `0.0.1`); run with `0.2.0` + new hash; version, sha256, and url all updated; `app` and `caveats` lines untouched
- `test_fails_on_unrelated_file`: a cask-named file whose first line is `cask "someotherapp"`; script exits 1 and does not modify the file

- [ ] **Step 2: Run the tests to verify they fail**

Run: `ruby scripts/update-homebrew-cask-test.rb`
Expected: FAIL — script doesn't exist yet

- [ ] **Step 3: Implement the script**

Ruby 2.6 stdlib only. Template literal for creation; targeted `sub!` rewrites for update (anchored on `version "`, `sha256 arm64: "`, and the `url "` line prefix); the guard check from the Interfaces block.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `ruby scripts/update-homebrew-cask-test.rb`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add scripts/update-homebrew-cask.rb scripts/update-homebrew-cask-test.rb
git commit -m "feat: tap cask updater with template creation and guarded rewrite"
```

### Task 4: Release workflow `.github/workflows/release.yml`

**Files:**
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: Tasks 1–3 scripts; secrets `HOMEBREW_TAP_TOKEN` (fine-grained PAT, `contents: write` on `travmik/homebrew-tap`); built-in `GITHUB_TOKEN` for the Release
- Produces: on tag push `v*` — GitHub Release with `ShiftHappens-v<version>-arm64.tar.gz` attached, notes auto-generated; tap cask updated and pushed as `shift-happens vX.Y.Z`

- [ ] **Step 1: Write the workflow**

Structure:
- Triggers: `push: tags: ['v*']` and `workflow_dispatch` (for testing without tagging)
- `runs-on: macos-14`; `permissions: contents: write`
- Steps: checkout → `swift build -c release` → `./scripts/make-release-artifact.sh "$GITHUB_REF_NAME"` → parse `artifact=`/`sha256=` lines → `gh release create "$GITHUB_REF_NAME" "$ARTIFACT" --generate-notes --verify-tag` (env `GH_TOKEN: ${{ github.token }}`) → tap update step:
  - Guard first: `test -n "$HOMEBREW_TAP_TOKEN"` else `exit 1` with message "HOMEBREW_TAP_TOKEN secret is not set — skipping tap update" (exit nonzero so the failure is visible)
  - `git clone https://x-access-token:${HOMEBREW_TAP_TOKEN}@github.com/travmik/homebrew-tap.git`
  - `ruby ../scripts/update-homebrew-cask.rb Casks/shift-happens.rb "$VERSION" "$SHA256" travmik/shift-happens`
  - commit `-m "shift-happens v$VERSION"` and push

- [ ] **Step 2: Verify statically**

Run: `ruby -ryaml -e 'YAML.load_file(".github/workflows/release.yml"); puts "YAML OK"'`
Expected: `YAML OK`

Run: `grep -c 'HOMEBREW_TAP_TOKEN' .github/workflows/release.yml`
Expected: `2` (guard + clone URL; proves the guard exists)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: tag-driven release pipeline — build, GitHub Release, tap update"
```

### Task 5: Documentation

**Files:**
- Create: `docs/adr/0002-unsigned-tap-distribution.md`
- Modify: `docs/adr/README.md` (index row for 0002)
- Modify: `README.md` (Install section: `brew tap travmik/tap https://github.com/travmik/homebrew-tap` + `brew install --cask travmik/tap/shift-happens`; Accessibility caveat; "Releasing" subsection: tag and push)
- Modify: `CHANGELOG.md` (under `[Unreleased]` → Added: Homebrew cask distribution via personal tap)
- Modify: `AGENTS.md` and `CLAUDE.md` (signing quirk wording: stable identity is for **local dev** builds only; release builds are ad-hoc — reference ADR 0002)

- [ ] **Step 1: Write ADR 0002** — Context (no Apple Developer account; Homebrew quarantines by default; Sequoia Gatekeeper), Decision (ad-hoc release builds, tar.gz artifact, personal tap, manual Accessibility grant, re-grant per update), Alternatives (Developer ID notarization $99/yr — rejected for now; .zip — rejected, carries quarantine; official cask repo — later), Consequences (re-grant per update; local dev keeps `keyboard-switcher-dev`; CLAUDE.md rule scoped to local builds)
- [ ] **Step 2: Update README, CHANGELOG, ADR index, AGENTS.md, CLAUDE.md** per the Files list; keep existing tone and tables
- [ ] **Step 3: Verify** — no broken relative links (`ls` each target path mentioned); CHANGELOG renders (eyeball)
- [ ] **Step 4: Commit**

```bash
git add docs CHANGELOG.md README.md AGENTS.md CLAUDE.md
git commit -m "docs: homebrew distribution — ADR 0002, install instructions, release procedure"
```

### Task 6: Maintainer setup and first release

**Files:**
- No repo files (external setup + tag)

**Interfaces:**
- Consumes: Tasks 1–5 merged to `main` on GitHub; `gh` authenticated as `travmik`
- Produces: `travmik/homebrew-tap` repo with `Casks/shift-happens.rb`; `HOMEBREW_TAP_TOKEN` secret set; installable cask

- [ ] **Step 1: Create the tap repo** (agent-run, `gh` is authenticated):

```bash
gh repo create travmik/homebrew-tap --public --description "Homebrew tap — casks by travmik" --clone=false
```

- [ ] **Step 2: Push a minimal initial commit** to the tap (README only) so `git clone` in CI works before the first release
- [ ] **Step 3: Create the PAT** (maintainer, manual — tokens cannot be created via `gh`): GitHub → Settings → Developer settings → Fine-grained tokens → only `travmik/homebrew-tap`, permission `Contents: Read and write`. Then: `gh secret set HOMEBREW_TAP_TOKEN --repo travmik/shift-happens` (paste value)
- [ ] **Step 4: Smoke-run the workflow without tagging**: `gh workflow run release.yml --repo travmik/shift-happens` → watch `gh run watch`; expect the release step to fail on `--verify-tag` (no tag) but **succeed** through build + artifact + reach the tap guard (validates Tasks 1–3 end-to-end). If build or artifact fails, fix before tagging.
- [ ] **Step 5: Tag the first release**:

```bash
git tag v0.1.0 && git push origin v0.1.0
```
Watch the run to completion: Release created with the tar.gz; tap cask committed and pushed.

- [ ] **Step 6: Verify the cask end-to-end** (maintainer's machine):

```bash
brew install --cask travmik/tap/shift-happens
```
Expected: installs into /Applications, **no Gatekeeper prompt**; app launches and shows the Accessibility "not granted" state; works after granting.
Then: `brew uninstall --cask travmik/tap/shift-happens` removes it cleanly.
Then verify the upgrade path (spec acceptance item 4): bump-tag `v0.1.1`, wait for the pipeline, `brew upgrade --cask travmik/tap/shift-happens`, expect the Accessibility re-grant prompt and a working app.

- [ ] **Step 7: Record acceptance** — flip the spec's Status line to "implemented (v0.1.0)"; commit:

```bash
git add docs/superpowers/specs/2026-10-22-homebrew-tap-distribution-design.md
git commit -m "docs: homebrew tap distribution implemented — spec status update"
```
