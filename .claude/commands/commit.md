---
description: Generate Conventional Commit for AudioPin staged changes
argument-hint: [optional scope or note]
---

# Commit (AudioPin)

Project-specific override. Inherits global rules from `~/.claude/commands/commit.md`. Differences below.

## Workflow

1. `git diff --cached` + `git status` (parallel).
2. If nothing staged → stop, tell user.
3. Pick `type` + AudioPin scope.
4. Write subject. Body only when "why" non-obvious.
5. Show user. Do not commit unless confirmed.

## AudioPin Scopes

`infra`, `domain`, `ui`, `pin`, `gain`, `profile`, `menubar`, `settings`, `prd`.

Map by file location:
- `Infrastructure/` → `infra`
- `Domain/DevicePinEngine.*` → `pin`
- `Domain/GainLockEngine.*` → `gain`
- `Domain/ProfileStore.*` → `profile`
- `Domain/*` (other) → `domain`
- `UI/MenuBar*` → `menubar`
- `UI/Settings*` → `settings`
- `UI/*` (other) → `ui`
- `PRD.md` → `prd`

## Format + Rules

Same as global. Conventional Commits. Subject ≤ 50 chars, imperative, no period. Body wrapped 72, explains why. No emojis. No `Co-Authored-By` unless asked.

## Examples

```
feat(pin): add UID-first device match with name fallback

UIDs survive renames but not firmware resets. Fallback to
lastKnownName when UID lookup fails, then refresh on hit.
```

```
fix(gain): iterate per-channel elements on USB mics

Volume property lives on elements 1+2, not Main. Reading
Main returned nil on Shure MV7.
```

```
docs(prd): add export/import as MVP feature
```

$ARGUMENTS
