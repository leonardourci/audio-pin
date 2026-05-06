# AudioPin — Git Commit Guidelines

## Format

Conventional Commits.

```
<type>(<scope>): <subject>

<body>

<footer>
```

## Rules

- Subject ≤ 50 chars, imperative mood ("add", not "added"/"adds"). No trailing period.
- Body wrapped at 72 chars. Explain **why**, not **what** — diff already shows what.
- Skip body when intent is obvious from subject.
- One logical change per commit. No drive-by refactors.
- No emojis. No "Co-Authored-By" unless user explicitly asks.

## Types

| Type | Use for |
|------|---------|
| `feat` | New user-visible feature |
| `fix` | Bug fix |
| `refactor` | Code change, no behavior change |
| `perf` | Performance improvement |
| `test` | Test-only changes |
| `docs` | Docs / PRD / README only |
| `build` | Xcode project, build settings, CI |
| `chore` | Tooling, deps, housekeeping |

## Scopes (AudioPin-specific)

`infra`, `domain`, `ui`, `pin`, `gain`, `profile`, `menubar`, `settings`, `prd`.

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

## Anti-patterns

- ❌ `update code`
- ❌ `WIP`
- ❌ `fix bug` (which bug?)
- ❌ Mixing feature + refactor in one commit
- ❌ Long narrative subject; put narrative in body
