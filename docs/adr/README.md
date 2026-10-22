# Architecture Decision Records

This directory records significant architectural decisions for Shift Happens.

## Conventions

- One decision per file, named `NNNN-short-title.md` (zero-padded, sequential).
- Status lifecycle: `Proposed` → `Accepted` (or `Rejected`) → eventually
  `Superseded by NNNN-...`.
- **Accepted ADRs are immutable.** To change a decision, write a new ADR that
  supersedes the old one and update the old ADR's status link only.
- Write an ADR when a choice between real alternatives affects structure, APIs,
  dependencies, permissions, or system interactions. Trivial choices don't
  warrant one.

## Template

```markdown
# NNNN. Title

Date: YYYY-MM-DD
Status: Proposed | Accepted | Rejected | Superseded by NNNN

## Context
What problem or force prompted this decision?

## Decision
What was decided, in one or two sentences.

## Alternatives considered
What else was on the table, and why it was not chosen.

## Consequences
What becomes easier, harder, or newly required.
```

## Index

| ADR | Title | Status |
|---|---|---|
| [0001](0001-spec-driven-development-workflow.md) | Spec-driven development workflow and documentation layout | Accepted |
| [0002](0002-unsigned-tap-distribution.md) | Unsigned Homebrew tap distribution | Accepted |
