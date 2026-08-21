# AGENTS.md

## Source of Truth

`SPEC.md` is the source of truth for product behavior.

## Development Principles

- SwiftUI first
- SwiftData for local persistence
- Prefer native Apple frameworks
- Avoid unnecessary third-party dependencies
- Do not add backend infrastructure without explicit approval
- Do not implement GitHub write operations
- GitHub integration must remain read-only
- Do not integrate Claude API
- Keep Views small and reusable
- Business logic should not live directly inside Views
- Use async/await for asynchronous operations
- Handle calendar/timezone logic explicitly
- Widget and app must share only the minimum required state
- Never hardcode credentials or tokens

## Before Implementing

1. Read `SPEC.md`.
2. Inspect the existing repository.
3. Reuse existing patterns when possible.
4. State the files/components that need to change.

## After Implementing

1. Build the project.
2. Run available tests.
3. Fix warnings introduced by the change.
4. Report changed files.
5. Report validation results.

## Scope

Do not silently expand the requested scope.
