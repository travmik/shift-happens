# 0001. Spec-driven development workflow and documentation layout

Date: 2026-10-22
Status: Accepted

## Context

Shift Happens is developed with AI agents as first-class contributors. Without a
fixed workflow, agent-driven work tends to jump straight to code: requirements
stay implicit, plans are invented mid-implementation, and decisions live only in
chat history. The project already used Superpowers conventions (specs under
`docs/superpowers/specs/`, plans under `docs/superpowers/plans/`) for increment 1,
but the layout was undocumented and there was no home for decision records or a
changelog.

## Decision

1. All non-trivial work follows the pipeline:
   **idea → brainstorm → written spec → spec review → plan → TDD implementation →
   verification → docs/changelog update**.
2. Documentation lives in fixed locations:

   | Artifact | Location |
   |---|---|
   | Product concept (source of truth) | `docs/concept.md` |
   | Design specs | `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` |
   | Implementation plans | `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` |
   | Decision records | `docs/adr/NNNN-title.md` |
   | Changelog | `CHANGELOG.md` |

3. Agent-facing instructions live in `AGENTS.md` (methodology, doc map, git
   conventions, validation commands) with deep technical quirks kept in
   `CLAUDE.md`. Pi project settings live in `.pi/settings.json` and are minimal
   (pinned provider/model only).

## Alternatives considered

- **A single `docs/design.md` per feature** — simpler, but loses the separation
  between *what to build* (spec) and *in what order* (plan) that makes review
  gates and independent task verification practical.
- **Keep everything in chat history** — rejected: decisions evaporate; specs,
  plans, and ADRs are the durable record.
- **Put decision records in `docs/superpowers/`** — rejected: ADRs are
  agent-agnostic project artifacts, not tied to the Superpowers tooling layout.

## Consequences

- Every feature produces two reviewable artifacts (spec, plan) before code.
- Accepted ADRs are immutable; superseding requires a new numbered record.
- `CHANGELOG.md` must be updated as part of each change, not deferred.
- Superpowers skill outputs (specs, plans) drop into the documented locations by
  default — no path negotiation per session.
