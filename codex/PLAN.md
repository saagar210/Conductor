# Delta Plan

## A) Executive Summary

### Current state (repo-grounded)
- Native macOS app in SwiftUI + SwiftData with app entry in `Conductor/ConductorApp.swift`.
- Session ingestion pipeline exists: discovery (`SessionDiscovery`) -> parser (`JSONLParser`) -> model builder (`SessionBuilder`).
- Latest commit added polling-based live sync and fingerprint planner (`Conductor/Parsing/SessionSyncPlanner.swift`).
- Polling currently updates changed sessions but does not model removed sessions and may run duplicate monitor loops if view task restarts.
- Tests include parser/model/simulation and new planner tests (`ConductorTests/SessionSyncPlannerTests.swift`).
- Build/test execution is environment-limited due to missing `xcodebuild`.

### Key risks
- Duplicate monitor loops can cause unnecessary filesystem churn and repeated writes.
- Removed sessions are not explicitly reconciled against persisted store.
- Selection state can become stale if selected session disappears or rebuild fails.
- Fingerprint does not encode subagent topology changes.
- Existing verification cannot run full suite in this environment.

### Improvement themes (priority)
1. Harden sync planning contract (changed + removed + fingerprint quality).
2. Harden monitor lifecycle (single loop guarantee).
3. Improve sync reconciliation behavior for selection, removed data, and mock fallback transitions.
4. Expand planner tests for regressions.

## B) Constraints & Invariants (Repo-derived)

### Explicit invariants
- App uses SwiftData models: `Session`, `AgentNode`, `CommandRecord`, `ToolCallRecord`.
- Session import path should continue to support mock fallback when no discovered sessions on initial import.
- Manual refresh (`⌘R`) remains available and functional.

### Implicit invariants (inferred)
- Selected node should reset when selected session changes (from `AppState` didSet behavior).
- Session list relies on persisted `Session.logPath` uniqueness for mapping discovered sessions.
- Discovery and parsing should not crash on malformed/missing logs; best-effort behavior is expected.

### Non-goals
- No schema migration in SwiftData models.
- No change to parser/session builder semantics beyond sync orchestration.
- No UI redesign.

## C) Proposed Changes by Theme

### Theme 1: Sync planner contract
- Current: planner returns only changed sessions by size/date.
- Proposed: add `SyncPlan` with `changed` and `removedLogPaths`; include subagent path signature in fingerprint.
- Why: robust reconciliation and reduced stale data.
- Tradeoff: slightly richer planner API; minimal caller changes.
- Scope: planner + tests only.

### Theme 2: Monitor lifecycle
- Current: `.task` awaits monitor loop; potential restarts could start multiple loops.
- Proposed: maintain single monitor task handle in app state and idempotent start/stop.
- Why: avoid duplicate polling loops.
- Tradeoff: slightly more state in app.
- Scope: `ConductorApp` only.

### Theme 3: Sync reconciliation
- Current: changed sessions rebuilt; removed sessions ignored.
- Proposed: delete removed sessions, rebuild changed, repair selection if needed, and clear mock data when real sessions are discovered.
- Why: maintain accurate persisted store and stable UX.
- Scope: `ConductorApp` only.

### Theme 4: Regression tests
- Current: planner tests only cover changed/new/unchanged.
- Proposed: add coverage for removed session detection and subagent-signature changes.
- Why: protect planner contract.

## D) File/Module Delta (Exact)

### ADD
- None planned.

### MODIFY
- `Conductor/Parsing/SessionSyncPlanner.swift` — richer sync plan + stronger fingerprint.
- `Conductor/ConductorApp.swift` — monitor lifecycle + reconciliation hardening.
- `ConductorTests/SessionSyncPlannerTests.swift` — add tests for removed/subagent changes.
- `codex/*.md` artifacts — planning, checkpoints, decisions, verification, changelog draft.

### REMOVE/DEPRECATE
- None planned.

### Boundary rules
- Keep planner pure (no SwiftData dependency).
- Keep App-level orchestration in `ConductorApp` (no parser/model changes).

## E) Data Models & API Contracts (Delta)

- Current contract: `SessionSyncPlanner.changedSessions(...) -> [DiscoveredSession]`.
- Proposed contract: `SessionSyncPlanner.plan(...) -> SessionSyncPlan` where plan contains `changedSessions` and `removedLogPaths`.
- Compatibility: internal-only; callers updated in same commit.
- Persistence migration: none.
- Versioning: not public API.

## F) Implementation Sequence

1. **Planner contract upgrade**
   - Files: `SessionSyncPlanner.swift`
   - Preconditions: existing planner tests present.
   - Verify: source inspection + tests (environment-limited execution).
   - Rollback: restore old planner interface.

2. **App sync reconciliation hardening**
   - Files: `ConductorApp.swift`
   - Dependencies: Step 1.
   - Verify: source inspection, ensure selection fallback path.
   - Rollback: revert to previous sync behavior.

3. **Tests update**
   - Files: `SessionSyncPlannerTests.swift`
   - Dependencies: Step 1.
   - Verify: run test commands (not executable here), static compile sanity review.
   - Rollback: revert added tests.

4. **Documentation/checkpoint updates**
   - Files: `codex/*`
   - Verify: consistency and completeness.

## G) Error Handling & Edge Cases

- Handle discovered set shrinking (session files deleted) via `removedLogPaths`.
- If selected session deleted or rebuild fails, auto-select most recent remaining session.
- Preserve no-crash behavior with discovery failures by no-op when no plan changes.
- Ensure monitor task cancellation on app refresh/restart path.

## H) Integration & Testing Strategy

- Integration points: planner -> app sync loop.
- Unit tests: planner contract with removed/subagent cases.
- Regression intent: avoid stale sessions and missed updates.
- DoD:
  - planner supports removed + changed detection,
  - app applies plan deterministically,
  - tests updated,
  - docs/checkpoints complete.

## I) Assumptions & Judgment Calls

- Assumption: `logPath` is stable unique key for persisted sessions.
- Assumption: subagent file set changes should trigger rebuild.
- Judgment call: keep polling (2s) rather than introducing file event stream in this delta to remain low risk.
- Alternative deferred: incremental append parser with per-line state tracking.
