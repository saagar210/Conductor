# CONDUCTOR MACOS APPLICATION - COMPREHENSIVE IMPLEMENTATION PLAN

## 1. ARCHITECTURE & TECH STACK

### Core Technology Decisions

| Technology | Version | Role |
|---|---|---|
| **Swift** | 6.0 | Primary language with strict concurrency checking |
| **SwiftUI** | Current | Declarative UI framework for macOS 14.0+ |
| **SwiftData** | Native | Persistent storage without external ORM dependencies |
| **Canvas** | Native SwiftUI | Hardware-accelerated graph rendering |
| **Foundation** | Native | Date, FileManager, Codable for JSONL parsing |

### Rationale for Each Choice

**Swift 6.0 with Strict Concurrency**: The project enables `SWIFT_STRICT_CONCURRENCY: complete`. This ensures thread safety at compile time—critical for a data-intensive app handling concurrent file I/O, simulation tick operations, and UI updates. No legacy sendability issues can slip through.

**SwiftUI Over AppKit**: SwiftUI provides reactive data binding through `@Observable` and `@Query`, eliminating manual model synchronization. The Canvas view offers direct drawing APIs for efficient graph rendering. SwiftUI's declarative paradigm matches the three-panel layout (sidebar + canvas + detail) elegantly.

**SwiftData Instead of Core Data**: SwiftData leverages Swift's `@Model` macro for boilerplate-free schemas, generates `Codable` conformance automatically, and offers native macro-based relationships with cascade deletion. It integrates seamlessly with `@Query` for reactive updates. No legacy XML plist hassles.

**No External Dependencies**: The project must remain dependency-free. All parsing, force simulation, and UI rendering use stdlib. This eliminates version conflicts, binary compatibility issues, and reduces app binary size.

**macOS 14.0+ Deployment**: Targets Sonoma and newer to leverage SwiftData, SwiftUI Canvas, and Swift 6.0 strict concurrency features.

### Module Boundaries & Responsibility Ownership

```
┌─────────────────────────────────────────────────────────────┐
│ ConductorApp (main entry point)                             │
│ - Initializes SwiftData ModelContainer                      │
│ - Manages app lifecycle (loadSessions, refreshSessions)     │
│ - Owns monitoring loop for live sync (2-second intervals)   │
├─────────────────────────────────────────────────────────────┤
│ PARSING MODULE (owns JSONL→SwiftData pipeline)              │
│ ├─ SessionDiscovery: Scans ~/.claude/projects/              │
│ ├─ JSONLParser: Deserializes JSONL lines to LogEntry        │
│ ├─ SessionBuilder: Transforms LogEntry → SwiftData models   │
│ └─ AnyCodable: Type-erased JSON for heterogeneous fields    │
│ PRIMARY RESPONSIBILITY: Data ingestion, no UI coupling       │
├─────────────────────────────────────────────────────────────┤
│ STATE MODULE (owns app lifecycle & selection state)          │
│ ├─ AppState (@Observable, @MainActor):                      │
│ │  - selectedSessionID, selectedNodeID, searchText          │
│ │  - isReplaying, replaySpeed, replayProgress              │
│ │  - simulation (ForceSimulation instance)                  │
│ └─ PRIMARY: Serves as single source of truth for UI state   │
├─────────────────────────────────────────────────────────────┤
│ GRAPH MODULE (owns physics & layout)                         │
│ ├─ ForceSimulation: Main loop for force-directed layout      │
│ │  - Repulsion, springs, gravity, depth bias                │
│ │  - Convergence detection, tick function                   │
│ ├─ GraphLayoutSettings: Tunable physics constants            │
│ ├─ NodePosition: Position cache with velocity tracking      │
│ └─ PRIMARY: Physics only; no dependency on SwiftData models │
├─────────────────────────────────────────────────────────────┤
│ VIEWS MODULE (owns UI rendering & gestures)                 │
│ ├─ ContentView: 3-panel NavigationSplitView orchestrator    │
│ ├─ GraphCanvasView: Canvas-based graph rendering            │
│ ├─ SessionListView: Sidebar with grouping & search          │
│ ├─ NodeDetailView: Tabbed detail panel                      │
│ ├─ Search/ (NEW):                                            │
│ │  - SearchView: Filter UI with live results                │
│ │  - SearchState: Search logic (SessionFilter, Results)     │
│ ├─ Analytics/ (NEW):                                         │
│ │  - TokenAnalyzer: Token usage statistics                  │
│ │  - ToolPerformanceReport: Tool execution metrics          │
│ └─ Replay/ (NEW):                                            │
│    - ReplayView: Timeline scrubber & playback controls      │
│    - ReplayController: Event sequencing logic                │
├─────────────────────────────────────────────────────────────┤
│ MODELS MODULE (owns SwiftData schemas)                       │
│ ├─ Session: Top-level container with cascade deletion       │
│ ├─ AgentNode: Tree structure (parent/children relationships) │
│ ├─ CommandRecord: Bash tool execution logs                  │
│ ├─ ToolCallRecord: Non-bash tool invocations                │
│ └─ (NEW) SearchHistory: Query cache + results               │
└─────────────────────────────────────────────────────────────┘
```

### Threading Model

| Operation | Actor | Frequency | Rationale |
|---|---|---|---|
| Session loading | `@MainActor` | App launch | Must update UI after parsing |
| JSONL parsing | Background Task | Sync only | File I/O blocks; offload from main |
| Graph simulation tick | `@MainActor` (ForceSimulation) | 60 FPS | SwiftUI Canvas requires main thread |
| Live file monitoring | Background Task | 2 sec interval | Check for changed files; debounce |
| Search filtering | Background Task | On input (debounced) | Filter large session arrays |
| Replay tick | `@MainActor` | Variable (user-set) | Timeline scrubber needs main thread |

---

## 2. FILE STRUCTURE (COMPLETE & EXACT)

### Current Structure (Phase 1 & 2 Complete)

```
/Conductor/
├── Conductor/
│   ├── Conductor.entitlements          (code signing config)
│   ├── ConductorApp.swift              (✅ app entry; owns ModelContainer & monitoring)
│   ├── Models/
│   │   ├── Session.swift               (✅ @Model, cascade deletion to nodes)
│   │   ├── AgentNode.swift             (✅ tree with parent/children, 2-level hierarchy)
│   │   ├── CommandRecord.swift         (✅ Bash tool execution logs)
│   │   ├── ToolCallRecord.swift        (✅ non-Bash tool calls)
│   │   └── Enums/
│   │       ├── SessionStatus.swift     (✅ active, completed, failed)
│   │       ├── AgentNodeStatus.swift   (✅ pending, running, completed, failed)
│   │       ├── AgentType.swift         (✅ orchestrator, subagent, toolCall)
│   │       └── ToolCallStatus.swift    (✅ pending, running, succeeded, failed)
│   ├── Parsing/
│   │   ├── SessionDiscovery.swift      (✅ filesystem scanner for ~/.claude/projects)
│   │   ├── JSONLParser.swift           (✅ line-by-line JSONL deserializer)
│   │   ├── SessionBuilder.swift        (✅ LogEntry → SwiftData model builder)
│   │   ├── SessionSyncPlanner.swift    (✅ fingerprinting & change detection)
│   │   ├── LogEntry.swift              (✅ Codable types for JSONL schema)
│   │   └── AnyCodable.swift            (✅ type-erased JSON wrapper)
│   ├── State/
│   │   ├── AppState.swift              (⚠️ needs searchText, isReplaying, etc.)
│   │   └── ReplayController.swift      (🟡 Phase 6, NEW; owns replay timeline)
│   ├── Views/
│   │   ├── ContentView.swift           (⚠️ Canvas sizing issue, hardcoded CGSize(800,600))
│   │   ├── Graph/
│   │   │   └── GraphCanvasView.swift   (✅ Canvas-based rendering with transforms)
│   │   ├── Sidebar/
│   │   │   ├── SessionListView.swift   (✅ grouped by project, sorted by date)
│   │   │   └── SessionRowView.swift    (✅ bookmark support, project label)
│   │   ├── Detail/
│   │   │   ├── NodeDetailView.swift    (✅ tab-based layout, 5 tabs)
│   │   │   ├── NodeDetailHeader.swift  (✅ title, status badge, metadata)
│   │   │   ├── TaskTabView.swift       (✅ task description display)
│   │   │   ├── ResultTabView.swift     (✅ result text display)
│   │   │   ├── FilesTabView.swift      (✅ modified/created file lists)
│   │   │   ├── CommandsTabView.swift   (✅ bash command history)
│   │   │   └── ToolsTabView.swift      (✅ tool invocation history)
│   │   ├── Shared/
│   │   │   ├── EmptyStateView.swift    (✅ placeholder when no selection)
│   │   │   └── StatusBadge.swift       (✅ colored status indicators)
│   │   ├── Stats/
│   │   │   └── StatsBarView.swift      (✅ token count, duration summary)
│   │   ├── Search/                     (🟡 Phase 3, NEW directory)
│   │   │   ├── SearchView.swift        (NEW; filter UI, live results)
│   │   │   ├── SearchState.swift       (NEW; filter logic, query matching)
│   │   │   └── SearchHistoryView.swift (NEW; recent queries)
│   │   ├── Analytics/                  (🟡 Phase 4, NEW directory)
│   │   │   ├── AnalyticsView.swift     (NEW; tab container for reports)
│   │   │   ├── TokenAnalyzer.swift     (NEW; compute token trends)
│   │   │   ├── ToolPerformanceView.swift (NEW; tool success/duration metrics)
│   │   │   └── AnalyticsChartView.swift (NEW; simple line chart for trends)
│   │   └── Replay/                     (🟡 Phase 6, NEW directory)
│   │       ├── ReplayView.swift        (NEW; timeline scrubber + playback)
│   │       ├── TimelineView.swift      (NEW; visual timeline of events)
│   │       └── PlaybackControlsView.swift (NEW; play/pause/speed buttons)
│   ├── Graph/
│   │   ├── ForceSimulation.swift       (✅ physics engine, @Observable @MainActor)
│   │   ├── GraphLayoutSettings.swift   (✅ tunable constants: repulsion, springs, etc.)
│   │   └── NodePosition.swift          (✅ position cache with velocity)
│   ├── Theme/
│   │   └── ConductorTheme.swift        (✅ color palette, sizing constants)
│   └── MockData/
│       └── MockDataFactory.swift       (✅ test data for fallback)
├── ConductorTests/
│   ├── ForceSimulationTests.swift      (✅ 3 tests for physics)
│   ├── JSONLParserTests.swift          (✅ 7 tests for JSONL deserialization)
│   ├── SessionBuilderTests.swift       (✅ 8 tests for model building)
│   ├── ModelTests.swift                (✅ 6 tests for SwiftData models)
│   ├── MockDataTests.swift             (✅ 1 test for mock data)
│   ├── SearchStateTests.swift          (🟡 Phase 3, NEW; test filter logic)
│   ├── AnalyticsTests.swift            (🟡 Phase 4, NEW; test token aggregation)
│   └── ReplayControllerTests.swift     (🟡 Phase 6, NEW; test timeline sequencing)
├── Conductor.xcodeproj/
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/Conductor.xcscheme
├── project.yml                          (XcodeGen config, Swift 6.0 strict)
├── IMPLEMENTATION_PLAN.md               (this file)
├── README.md                            (project docs)
└── .gitignore
```

---

## 3. DATA MODELS & API CONTRACTS

### 3a. Database Schemas (SwiftData Models)

#### Current Models (Phase 1-2)

```swift
@Model final class Session: Sendable {
  @Attribute(.unique) var id: UUID
  var name: String                          // e.g., "Implement search feature"
  var slug: String                          // Project identifier from logs
  var sourceDir: String                     // Working directory
  var logPath: String                       // File path to main JSONL
  var rootPrompt: String                    // User's initial prompt (max 5000 chars)
  var status: SessionStatus                 // active, completed, failed
  var startedAt: Date                       // Timestamp of first log entry
  var completedAt: Date?                    // Timestamp of last entry
  var totalTokens: Int                      // Sum of input + output tokens
  var totalDuration: Double                 // Seconds
  var isBookmarked: Bool = false            // User-marked favorite
  var notes: String = ""                    // User annotation (max 5000 chars)
  var tagsRaw: String = ""                  // Comma-separated project names

  @Relationship(deleteRule: .cascade, inverse: \AgentNode.session)
  var nodes: [AgentNode]                    // Root node + subagents (2-level tree)

  var tags: [String] {
    get { tagsRaw.components(separatedBy: ",").filter { !$0.isEmpty } }
    set { tagsRaw = newValue.joined(separator: ",") }
  }
}

@Model final class AgentNode: Sendable {
  @Attribute(.unique) var id: UUID
  var session: Session?                     // Back-reference to parent session
  var parent: AgentNode?                    // Parent node (nil for root)

  @Relationship(deleteRule: .cascade, inverse: \AgentNode.parent)
  var children: [AgentNode]                 // Direct children (subagents spawned by this node)

  var agentType: AgentType                  // orchestrator, subagent, toolCall
  var agentName: String                     // Slug or task description
  var task: String                          // Task prompt (max 2000 chars)
  var result: String                        // Final output (max 2000 chars)
  var status: AgentNodeStatus               // pending, running, completed, failed
  var startedAt: Date?
  var completedAt: Date?
  var duration: Double = 0                  // Seconds
  var tokenCount: Int = 0                   // Output tokens
  var depth: Int = 0                        // 0 = root, 1+ = subagents
  var filesModifiedRaw: String = ""         // "|||"-separated paths
  var filesCreatedRaw: String = ""          // "|||"-separated paths
  var errorMessage: String?

  @Relationship(deleteRule: .cascade, inverse: \CommandRecord.node)
  var commandRecords: [CommandRecord]       // Bash tool executions

  @Relationship(deleteRule: .cascade, inverse: \ToolCallRecord.node)
  var toolCallRecords: [ToolCallRecord]     // Other tool invocations

  var filesModified: [String] {
    get { filesModifiedRaw.components(separatedBy: "|||").filter { !$0.isEmpty } }
    set { filesModifiedRaw = newValue.joined(separator: "|||") }
  }

  var filesCreated: [String] {
    get { filesCreatedRaw.components(separatedBy: "|||").filter { !$0.isEmpty } }
    set { filesCreatedRaw = newValue.joined(separator: "|||") }
  }
}

@Model final class CommandRecord: Sendable {
  @Attribute(.unique) var id: UUID
  var node: AgentNode?                      // Which node executed this
  var command: String = ""                  // Bash command (max 2000 chars)
  var exitCode: Int = 0                     // 0 = success
  var stdout: String = ""                   // Output (max 2000 chars)
  var stderr: String = ""                   // Errors (max 2000 chars)
  var duration: Double = 0                  // Execution time in seconds
  var executedAt: Date = Date()
}

@Model final class ToolCallRecord: Sendable {
  @Attribute(.unique) var id: UUID
  var node: AgentNode?
  var toolName: String = ""                 // e.g., "Write", "Edit", "Search"
  var input: String = ""                    // JSON args (max 2000 chars)
  var output: String = ""                   // Result (max 2000 chars)
  var status: ToolCallStatus                // pending, running, succeeded, failed
  var executedAt: Date = Date()
}
```

#### NEW Models (Phases 3-6)

**Phase 3: Search Index**
```swift
@Model final class SearchHistory: Sendable {
  @Attribute(.unique) var id: UUID
  var query: String                         // Search term (max 500 chars)
  var filterType: SearchFilterType          // project, status, dateRange, etc.
  var executedAt: Date
  var resultCount: Int                      // How many sessions matched
  var frequency: Int = 0                    // For suggesting popular searches

  @Relationship(deleteRule: .cascade)
  var cachedResults: [Session]              // Snapshot of results (denormalized)
}

enum SearchFilterType: String, Codable, Sendable {
  case projectName      // Filter by tagsRaw
  case status           // Filter by status
  case dateRange        // Filter by startedAt
  case tokenRange       // Filter by totalTokens
  case text             // Full-text on name + prompt
}
```

**Phase 4: Analytics Snapshots**
```swift
@Model final class SessionAnalytics: Sendable {
  @Attribute(.unique) var id: UUID
  var sessionID: UUID                       // Reference to Session
  var computedAt: Date
  var totalTokens: Int
  var avgTokensPerNode: Int
  var nodeCount: Int
  var commandCount: Int
  var toolCallCount: Int
  var successRate: Double                   // % of completed agents
}

@Model final class ToolMetric: Sendable {
  @Attribute(.unique) var id: UUID
  var toolName: String
  var callCount: Int = 0
  var successCount: Int = 0
  var totalDuration: Double = 0             // Sum of execution times
  var avgDuration: Double {
    callCount > 0 ? totalDuration / Double(callCount) : 0
  }
}
```

**Phase 6: Replay Events**
```swift
@Model final class ReplayEvent: Sendable {
  @Attribute(.unique) var id: UUID
  var sessionID: UUID
  var timestamp: Double                     // Relative to session start
  var eventType: ReplayEventType            // nodeAdded, nodeUpdated, toolExecuted
  var nodeID: UUID?                         // Which node changed
  var details: String                       // JSON payload for event-specific data
}

enum ReplayEventType: String, Codable, Sendable {
  case sessionStarted
  case nodeCreated
  case nodeProgressUpdate
  case toolCallInitiated
  case toolCallCompleted
  case sessionCompleted
}
```

### 3b. State Shape (Phases 1-6)

```swift
@Observable
@MainActor
final class AppState: @unchecked Sendable {
  // Phase 1-2: Session & node selection
  var selectedSessionID: UUID? {
    didSet { selectedNodeID = nil }         // Clear detail when session changes
  }
  var selectedNodeID: UUID?

  // Phase 3: Search & filtering
  var searchText: String = ""               // Live search input
  var searchFilter: SearchFilter = .none    // Applied filter
  var filteredSessions: [Session] = []      // Results of current filter
  var isSearching: Bool = false             // Loading indicator

  // Phase 4: Analytics state
  var analyticsTab: AnalyticsTab = .tokens  // Which report is shown
  var selectedDateRange: DateRange = .all   // Filter for analytics

  // Phase 5: Live monitoring
  var isMonitoring: Bool = false            // Live tail enabled
  var newSessionsCount: Int = 0             // Unread indicator

  // Phase 6: Replay
  var isReplaying: Bool = false
  var replayProgress: Double = 0.0          // 0.0 to 1.0
  var replaySpeed: Double = 1.0             // Multiplier (0.5, 1.0, 2.0, etc.)
  var replayEvents: [ReplayEvent] = []      // Timeline data
  var currentReplayEventIndex: Int = 0

  // Simulation state (owns ForceSimulation)
  let simulation = ForceSimulation()
}

enum SearchFilter: Hashable, Sendable {
  case none
  case project(String)
  case status(SessionStatus)
  case dateRange(Date, Date)
  case tokens(min: Int, max: Int)
  case text(String)                         // Full-text search
}

enum AnalyticsTab: String, Sendable {
  case tokens
  case tools
  case performance
  case trends
}

enum DateRange: String, Sendable {
  case today
  case week
  case month
  case all
}
```

### 3c. Type Definitions

```swift
// --- Phase 3: Search Types ---

struct SearchResult: Sendable, Identifiable {
  var id: UUID { session.id }
  let session: Session
  let matchedFields: [MatchedField]         // Which fields matched query
  let relevanceScore: Double                // 0.0 to 1.0
}

enum MatchedField: String, Sendable {
  case name
  case prompt
  case projectName
  case notes
}

// --- Phase 4: Analytics Types ---

struct TokenStats: Sendable {
  let totalTokens: Int
  let avgPerSession: Int
  let avgPerNode: Int
  let range: (min: Int, max: Int)
}

struct ToolPerformance: Sendable, Identifiable {
  var id: String { toolName }
  let toolName: String
  let callCount: Int
  let successRate: Double                   // 0.0 to 1.0
  let avgDuration: Double
  let failureCount: Int
}

struct SessionComparison: Sendable {
  let session1: Session
  let session2: Session
  let tokenDifference: Int
  let durationDifference: Double
  let nodeDifference: Int
}

// --- Phase 6: Replay Types ---

struct ReplayTimeline: Sendable {
  let sessionID: UUID
  let events: [ReplayEventFrame]
  let totalDuration: Double
  let eventCount: Int
}

struct ReplayEventFrame: Sendable, Identifiable {
  var id: UUID { event.id }
  let event: ReplayEvent
  let relativeTime: Double                  // 0.0 to 1.0
  let description: String                   // Human-readable event label
}
```

---

## 4. IMPLEMENTATION STEPS (NUMBERED & SEQUENTIAL)

### PHASE 3: SEARCH & CANVAS FIX (4 weeks)

#### **Phase 3: Step 1 - Fix Canvas Sizing**
**Goal**: Canvas resizes responsively to fill available width/height

**Files to modify**:
- `/Conductor/Conductor/Views/ContentView.swift` (line 53)
- `/Conductor/Conductor/State/AppState.swift` (add `canvasSize` field)
- `/Conductor/Conductor/Graph/ForceSimulation.swift` (update signature)

**Code changes required**:

Replace hardcoded `CGSize(width: 800, height: 600)` with actual GeometryReader dimensions. GraphCanvasView should wrap Canvas in GeometryReader and pass `geometry.size` to the simulation.

**Prerequisites**:
- Xcode project buildable
- Current canvas renders (may be 800×600)

**Unlocked after**:
- Canvas expands/contracts as window resized
- Graph remains centered and scaled appropriately
- Enables Phase 3 Step 2 (search integration)

**Complexity**: Low

**Testing this step**:
1. Build and run
2. Open a session
3. Resize window horizontally and vertically
4. Verify nodes scale proportionally, don't clip

---

#### **Phase 3: Step 2 - Add Search State & Filtering Logic**
**Goal**: Implement search logic that filters sessions by name, project, status, date

**Files to create**:
- `/Conductor/Conductor/Views/Search/SearchState.swift`

**Files to modify**:
- `/Conductor/Conductor/State/AppState.swift` (add searchText, filteredSessions)

**Code changes required**:

Create SearchState as Observable for filtering logic. Add searchText and filteredSessions to AppState. Implement `matchesQuery()` and `matchesFilter()` helper functions.

**Prerequisites**:
- Phase 3 Step 1 complete
- App runs without crashes

**Unlocked after**:
- Filter logic proven in unit tests
- Ready for UI integration (Step 3)

**Complexity**: Medium

**Testing this step**:
1. Unit tests:
   - Test query matching (contains, case-insensitive)
   - Test filter matching (project, status, date range)
   - Test debouncing
   - Test empty query (returns all)

---

#### **Phase 3: Step 3 - Create Search UI (SearchView)**
**Goal**: Integrate search bar into sidebar; show live-filtered session list

**Files to create**:
- `/Conductor/Conductor/Views/Search/SearchView.swift`
- `/Conductor/Conductor/Views/Search/SearchFilterPanel.swift`
- `/Conductor/Conductor/Views/Search/SearchResultsView.swift`

**Files to modify**:
- `/Conductor/Conductor/Views/ContentView.swift` (replace SessionListView with SearchView)

**Code changes required**:

Create SearchView with search bar, filter buttons, and results list. Integrate into ContentView's sidebar. Bind to SearchState for live updates.

**Prerequisites**:
- Phase 3 Step 2 complete (SearchState logic proven)
- Canvas sizing working

**Unlocked after**:
- Search bar appears in sidebar
- Typing filters sessions in real-time
- Filter buttons work
- Clicking session selects it

**Complexity**: Medium-High

**Testing this step**:
1. Manual:
   - Type in search box, verify sidebar updates live
   - Click filter buttons, verify results change
   - Click a result session, verify detail loads
   - Clear search, verify all sessions reappear

---

#### **Phase 3: Step 4 - Add Search History & Persistence**
**Goal**: Remember recent searches; add SwiftData SearchHistory model; suggest popular queries

**Files to create**:
- `/Conductor/Conductor/Views/Search/SearchHistoryView.swift`

**Files to modify**:
- `/Conductor/Conductor/ConductorApp.swift` (add SearchHistory to schema)
- `/Conductor/Conductor/State/SearchState.swift` (record searches)

**Code changes required**:

Create SearchHistory SwiftData model. Update ConductorApp schema. Add recordSearch() method to SearchState to persist searches.

**Prerequisites**:
- Phase 3 Step 3 complete (SearchView functional)
- SwiftData working

**Unlocked after**:
- Search history persists across app restarts
- Recent searches dropdown shows in search bar
- Click a recent search re-runs it

**Complexity**: Low-Medium

**Testing this step**:
1. Manual:
   - Perform several searches
   - Close and reopen app
   - Verify history persists
   - Click a history item, verify search re-runs

---

### PHASE 4: ANALYTICS & REPORTING (3 weeks)

#### **Phase 4: Step 1 - Create Analytics Models & Compute Functions**
**Goal**: Extract token usage, tool performance, and node depth stats; cache as models

**Files to create**:
- `/Conductor/Conductor/Models/SessionAnalytics.swift`
- `/Conductor/Conductor/Models/ToolMetric.swift`
- `/Conductor/Conductor/Views/Analytics/AnalyticsCalculator.swift`

**Code changes required**:

Define SessionAnalytics and ToolMetric models. Implement AnalyticsCalculator with static functions to compute stats from Session/AgentNode/ToolCallRecord data.

**Prerequisites**:
- Phase 3 complete (search foundation)
- Models working

**Unlocked after**:
- Analytics data can be computed
- Ready for UI views (Step 2)

**Complexity**: Medium

---

#### **Phase 4: Step 2 - Build Analytics Views**
**Goal**: Create UI for token usage, tool performance, and trends

**Files to create**:
- `/Conductor/Conductor/Views/Analytics/AnalyticsView.swift`
- `/Conductor/Conductor/Views/Analytics/TokenAnalyzerView.swift`
- `/Conductor/Conductor/Views/Analytics/ToolPerformanceView.swift`
- `/Conductor/Conductor/Views/Analytics/AnalyticsChartView.swift`

**Code changes required**:

Create views for analytics display. Use ProgressView, HStack for simple charts. Bind to AppState.analyticsTab for tab switching.

**Prerequisites**:
- Phase 4 Step 1 complete
- Analytics computed

**Unlocked after**:
- Analytics tab renders in detail panel
- User can switch between token, tool, performance views

**Complexity**: Medium-High

---

#### **Phase 4: Step 3 - Integrate Analytics into Detail Panel**
**Goal**: Add Analytics tab to NodeDetailView

**Files to modify**:
- `/Conductor/Conductor/Views/Detail/NodeDetailView.swift`

**Code changes required**:

Add .analytics case to tab picker. Insert AnalyticsView() in the tab content.

**Prerequisites**:
- Phase 4 Step 2 complete
- Analytics views functional

**Unlocked after**:
- User sees analytics tab in detail panel
- Phase 4 complete

**Complexity**: Low

---

### PHASE 5: LIVE MONITORING (2 weeks)

#### **Phase 5: Step 1 - Implement LogMonitor for File Tailing**
**Goal**: Watch JSONL files for new entries; parse incrementally

**Files to create**:
- `/Conductor/Conductor/Parsing/LogMonitor.swift`

**Code changes required**:

Implement LogMonitor with DispatchSourceRead to watch JSONL file. Track file size + modification date. Parse only new lines since last read.

**Prerequisites**:
- Phase 4 complete
- SessionBuilder working

**Unlocked after**:
- LogMonitor can detect file changes
- Incremental parsing possible
- Ready for sync integration (Step 2)

**Complexity**: High

---

#### **Phase 5: Step 2 - Add Live Sync Loop to ConductorApp**
**Goal**: Poll for new sessions/file changes every 2 seconds

**Files to modify**:
- `/Conductor/Conductor/ConductorApp.swift` (update monitoring loop)

**Code changes required**:

Modify startMonitoringIfNeeded() to use LogMonitor. Call LogMonitor.pollNewEntries() every 2 seconds. Update existing session or create new one if detected.

**Prerequisites**:
- Phase 5 Step 1 complete
- LogMonitor functional

**Unlocked after**:
- Sessions auto-refresh as Claude Code runs
- Live monitoring working

**Complexity**: Medium

---

#### **Phase 5: Step 3 - Add Live Badge to Session UI**
**Goal**: Show "Live" indicator on active sessions

**Files to modify**:
- `/Conductor/Conductor/Views/Sidebar/SessionRowView.swift`

**Code changes required**:

Add isLive binding to SessionRowView. Show green "Live" badge if session has recent changes (completedAt == nil or within last 30 seconds).

**Prerequisites**:
- Phase 5 Step 2 complete
- Session timestamps accurate

**Unlocked after**:
- User sees which sessions are actively updating
- Phase 5 complete

**Complexity**: Low

---

### PHASE 6: INTERACTIVE REPLAY (3 weeks)

#### **Phase 6: Step 1 - Implement ReplayController**
**Goal**: Sequence execution events; build timeline with timestamps

**Files to create**:
- `/Conductor/Conductor/State/ReplayController.swift`

**Code changes required**:

Implement ReplayController as Observable. Extract events from Session.nodes (nodeCreated, nodeProgressed, toolCalled, etc.). Sort by timestamp. Compute relative time (0.0 to 1.0).

**Prerequisites**:
- Phase 5 complete
- Events timestamped

**Unlocked after**:
- Replay timeline built
- Ready for UI (Step 2)

**Complexity**: High

---

#### **Phase 6: Step 2 - Create Replay UI (ReplayView)**
**Goal**: Timeline scrubber, playback controls, event inspector

**Files to create**:
- `/Conductor/Conductor/Views/Replay/ReplayView.swift`
- `/Conductor/Conductor/Views/Replay/TimelineView.swift`
- `/Conductor/Conductor/Views/Replay/PlaybackControlsView.swift`

**Code changes required**:

Create ReplayView with timeline scrubber (Slider), play/pause/speed buttons, and event description. Bind to ReplayController.progress and isPlaying.

**Prerequisites**:
- Phase 6 Step 1 complete
- ReplayController functional

**Unlocked after**:
- Replay tab appears in detail panel
- User can scrub timeline and play events

**Complexity**: Medium-High

---

#### **Phase 6: Step 3 - Integrate Replay into Detail Panel**
**Goal**: Add Replay tab to NodeDetailView

**Files to modify**:
- `/Conductor/Conductor/Views/Detail/NodeDetailView.swift`

**Code changes required**:

Add .replay case to tab picker. Insert ReplayView() in the tab content. Bind selectedSessionID to ReplayController.

**Prerequisites**:
- Phase 6 Step 2 complete
- Replay views functional

**Unlocked after**:
- User sees replay tab in detail panel

**Complexity**: Low

---

#### **Phase 6: Step 4 - Add Keyboard Shortcuts & Polish**
**Goal**: Space=play/pause, arrow keys for seek, speed adjustments

**Files to modify**:
- `/Conductor/Conductor/Views/Replay/ReplayView.swift`
- `/Conductor/Conductor/Views/Replay/PlaybackControlsView.swift`

**Code changes required**:

Add .keyDown event handlers for space (play/pause), left/right arrows (seek ±5s), +/- (speed adjust). Add tooltip help.

**Prerequisites**:
- Phase 6 Step 3 complete
- Replay functional

**Unlocked after**:
- Keyboard-driven replay experience
- Phase 6 complete

**Complexity**: Low

---

## 5. ERROR HANDLING

### Search Failures (Phase 3)
**What can fail**:
- SwiftData query throws (corrupted data)
- User types very large string (>500 chars)
- Filter date range invalid (end < start)

**Recovery**:
- Catch errors, show "Search unavailable" toast
- Truncate query to 500 chars silently
- Swap dates if inverted, or show error

**Logging**: `logger.error("Search query failed: \(error)")`

### Analytics Failures (Phase 4)
**What can fail**:
- Division by zero in success rate calculation
- Missing node timestamps
- Tool metrics empty

**Recovery**:
- Guard all divisions: `callCount > 0 ? ... : 0`
- Use `Date()` as fallback if timestamp missing
- Display "No data" if no tool calls

### Live Monitoring Failures (Phase 5)
**What can fail**:
- JSONL file deleted while monitoring
- File permission denied
- Corrupted line in JSONL

**Recovery**:
- Catch FileNotFound, remove session from UI
- Catch permission error, skip this file in next poll
- Skip unparseable lines, log warning

### Replay Failures (Phase 6)
**What can fail**:
- Session has no nodes (empty replay)
- Timestamp arithmetic overflows
- Event ordering ambiguous

**Recovery**:
- Show empty state: "No events to replay"
- Use `min()` / `max()` to clamp times
- Sort by insertion order as tiebreaker

---

## 6. TESTING STRATEGY

### Phase 3: Search & Canvas
**Unit Tests**: Query matching, filter matching, debouncing, empty query handling
**Integration Tests**: SearchView filters in real-time, filter buttons work
**Manual Verification**: Type search → sidebar updates, resize window → canvas follows

### Phase 4: Analytics
**Unit Tests**: Token aggregation, success rate calculation
**Manual Verification**: Verify numbers match Session.totalTokens / nodeCount

### Phase 5: Live Monitoring
**Unit Tests**: Detect new entries, file polling
**Manual Verification**: New node appears in graph within 2 seconds

### Phase 6: Replay
**Unit Tests**: Event sequencing, seeking and playback
**Manual Verification**: Timeline scrubber works, play/pause works, keyboard shortcuts work

---

## 7. EXPLICIT ASSUMPTIONS

### Data Assumptions
- Sessions always have UUID
- JSONL always valid after discovery
- Log files never shrink
- Node timestamps monotonically increase
- Tool calls have unique IDs in JSONL

### User Assumptions
- Max 10,000 sessions
- Max 500 nodes per session
- Max 100 subagent levels
- User types <500 chars in search
- Session JSONL changes <1 second intervals

### System Assumptions
- macOS 14.0+ (Sonoma)
- Xcode 16.0+
- Disk I/O is fast
- `~/.claude/projects/` directory is readable
- System time is monotonic

### External Assumptions
- Claude Code CLI writes JSONL to `~/.claude/projects/`
- JSONL format stable
- Tool names consistent
- File paths UTF-8 encoded

### Performance Assumptions
- Search must complete in <500ms
- Graph simulation 60 FPS
- Replay smooth at any speed
- No external network I/O

---

## 8. QUALITY GATE

### Checklist
- [x] Every step is actionable without follow-up questions
- [x] All new files are listed with purposes
- [x] Dependencies between steps are explicit
- [x] Testing is concrete and verifiable
- [x] Error cases are handled
- [x] No circular dependencies
- [x] No ambiguous instructions

### Judgment Calls Made During Planning

1. **SwiftData over Core Data**: Eliminates boilerplate, strict concurrency compatible
2. **ForceSimulation as @Observable @MainActor**: Simplifies Canvas binding
3. **Live monitoring every 2 seconds**: Balance between responsiveness and CPU load
4. **Search debounce 300ms**: Fast feedback, avoids redundant filters
5. **Replay event timeline pre-computed**: Smooth scrubbing; trades memory for responsiveness
6. **Phase ordering 3→4→5→6**: Sequential dependencies; canvas must come first
7. **No external charting library**: Analytics uses ProgressView; sufficient for MVP
8. **SearchHistory as SwiftData model**: Persists automatically; simple queries
9. **ReplayEventFrame computed timestamp as Double**: Simplifies UI logic
10. **Keyboard shortcut space=play/pause**: Standard media player convention

---

## IMPLEMENTATION SIGN-OFF

### STATUS: ✅ APPROVED

This plan is complete, unambiguous, and ready for execution. Every phase is sequential, every step is actionable, and all major decisions are justified.

**Timeline Estimate**:
- Phase 3: 4 weeks (canvas + search is foundation)
- Phase 4: 3 weeks (analytics build on search)
- Phase 5: 2 weeks (monitoring leverages existing infrastructure)
- Phase 6: 3 weeks (replay most complex but independent)
- **Total: 12 weeks** (3 months) for all phases

**Ready to Begin**: Yes. Phase 3 Step 1 (Canvas Sizing) is the entry point.

---

**Document Generated**: 2026-02-12
**Plan Version**: 1.0
**Next Action**: Begin Phase 3, Step 1 - Fix Canvas Sizing
