# Conductor

A native macOS app that visualizes [Claude Code](https://github.com/anthropics/claude-code) agentic workflows as interactive node graphs.

![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B-blue)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

**Phase 1** ✅ (Complete)
- Three-panel macOS interface (sidebar + force-directed graph + detail panel)
- Interactive force-directed graph with physics simulation
- Session management with bookmark support
- Real-time node selection and detail inspection
- Command execution history and tool call tracking

**Phase 2** ✅ (Complete)
- Real Claude Code JSONL log parsing
- Automatic session discovery from `~/.claude/projects/`
- Subagent delegation tree visualization
- Project-based session grouping
- Live session refresh (⌘R)

## Architecture

### Data Layer
- **SwiftData** models: `Session`, `AgentNode`, `CommandRecord`, `ToolCallRecord`
- Persistent storage with cascading delete relationships
- Self-referential tree structure for agent delegation

### Parsing Pipeline
```
SessionDiscovery → JSONLParser → SessionBuilder → SwiftData
```

1. **SessionDiscovery** — Scans `~/.claude/projects/` for session JSONL files
2. **JSONLParser** — Reads JSONL into lightweight `Codable` structs
3. **SessionBuilder** — Transforms log entries into SwiftData models
4. **AnyCodable** — Handles heterogeneous JSON for tool inputs/results

### Visualization
- **Force-directed graph** with:
  - Repulsion between nodes
  - Spring forces for parent-child relationships
  - Gravity to prevent drift
  - Depth bias for hierarchical layout
- Nodes sized by type (orchestrator > subagent > tool call)
- Color-coded by status (green = completed, blue = running, red = failed)

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 16.0+ (for building)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)
- Claude Code installed with active sessions in `~/.claude/projects/`

## Building

```bash
# Install XcodeGen (if needed)
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Open in Xcode
open Conductor.xcodeproj

# Build and run (⌘R in Xcode)
```

> **Note:** This project requires Xcode.app to build (not just CommandLineTools) due to SwiftData macro expansion requirements. Command-line builds via `swift build` are not supported.

## Usage

1. **Launch the app** — Conductor auto-discovers Claude Code sessions from `~/.claude/projects/`
2. **Select a session** — Click any session in the sidebar to load its agent graph
3. **Explore the graph** — Click nodes to view details: task, result, tool calls, commands
4. **Refresh sessions** — Press ⌘R or File → Refresh Sessions to reload from disk

If no real sessions are found, Conductor falls back to mock data for demonstration.

## Project Structure

```
Conductor/
├── Models/              # SwiftData models (Session, AgentNode, etc.)
├── Parsing/             # JSONL parsing and session discovery
│   ├── LogEntry.swift      # Codable types for JSONL format
│   ├── JSONLParser.swift   # Line-by-line JSONL reader
│   ├── SessionBuilder.swift # LogEntry → SwiftData transformation
│   ├── SessionDiscovery.swift # Filesystem scanner
│   └── AnyCodable.swift    # Type-erased JSON wrapper
├── Views/               # SwiftUI views
│   ├── Graph/              # Force-directed graph rendering
│   ├── Sidebar/            # Session list and filtering
│   └── Detail/             # Node detail panels
├── Simulation/          # Physics engine for graph layout
└── Theme/               # Colors, typography, layout constants

ConductorTests/
├── JSONLParserTests.swift      # 7 tests for JSONL parsing
├── SessionBuilderTests.swift   # 8 tests for session building
├── ModelTests.swift            # 6 tests for SwiftData models
├── ForceSimulationTests.swift  # 3 tests for physics
└── MockDataTests.swift         # 1 test for mock data factory
```

## Technical Highlights

- **Swift 6** with strict concurrency checking
- **@MainActor** isolation for SwiftUI and SwiftData
- **Sendable** protocol throughout for thread safety
- **Swift Testing** framework (not XCTest)
- **No external dependencies** — pure Swift/SwiftUI/SwiftData

## Roadmap

**Phase 3** (Planned)
- Real-time log tailing for active sessions
- Search and filter across all sessions
- Export graphs as PNG/SVG
- Token usage analytics and trends
- Session comparison view

**Phase 4** (Planned)
- Integration with Claude Code via IPC
- Live progress updates during session execution
- Interactive replay of agent decision-making
- Custom graph layouts (tree, radial, timeline)

## License

MIT License - see LICENSE file for details

## Credits

Built with [Claude Code](https://github.com/anthropics/claude-code) — an AI-powered coding assistant that this app visualizes.
