# Changelog Draft

## Theme: Live Sync Hardening
- Refactored planner contract from a single “changed sessions” list into a formal sync plan with:
  - `changedSessions`
  - `removedLogPaths`
- Strengthened fingerprinting by including a subagent file signature, so subagent additions/removals trigger rebuilds.
- Hardened app sync loop to:
  - enforce single monitor task,
  - delete sessions removed from disk,
  - rebuild changed sessions,
  - recover selected session when deletions/rebuilds occur,
  - remove mock fallback sessions once real sessions are discovered.

## Theme: Test Coverage
- Updated planner tests to new contract and added regression coverage for:
  - removed log-path detection,
  - subagent signature change detection.

## Theme: Session Artifacts / Resume Hygiene
- Added and maintained:
  - `codex/SESSION_LOG.md`
  - `codex/PLAN.md`
  - `codex/DECISIONS.md`
  - `codex/CHECKPOINTS.md`
  - `codex/VERIFICATION.md`
  - `codex/CHANGELOG_DRAFT.md`
