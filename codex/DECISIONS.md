# Decisions

## 2026-02-10

1. **Keep polling strategy (2 seconds) for this delta**
   - Rationale: minimal-risk fix to unsatisfactory prior change; avoids introducing event-stream complexity.
   - Alternative deferred: file descriptor based tailing and incremental parser state.

2. **Use `logPath` as reconciliation key**
   - Rationale: existing persisted `Session.logPath` already populated from discovery; avoids schema changes.

3. **Planner contract upgrade to explicit `SessionSyncPlan`**
   - Rationale: makes removed sessions first-class and reduces orchestration ambiguity.

4. **Delete mock sessions when real sessions appear**
   - Rationale: avoids mixed datasets and stale demo data after real discovery starts.
   - Scope-limited approach: detect mock by existing mock `logPath` convention `~/.claude/projects/...`.

5. **Use one monitor task handle in `ConductorApp`**
   - Rationale: prevents duplicate polling loops from repeated `.task` execution.
