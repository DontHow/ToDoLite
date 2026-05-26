# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TodoLite is a local-first, native SwiftUI todo app for iOS and macOS. It stores data as individual JSON files in iCloud Documents (not SwiftData/Core Data). Each todo, project, and tag is a separate JSON file. SQLite is used only for full-text search indexing, never as the source of truth.

## Build & Development

### Project Generation
This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen). The `.xcodeproj` is generated from `project.yml` and should not be edited manually.

```bash
xcodegen generate
```

### Build
```bash
# iOS
xcodebuild -project TodoLite.xcodeproj -scheme TodoLite-iOS -destination 'platform=iOS Simulator,name=iPhone 16'

# macOS
xcodebuild -project TodoLite.xcodeproj -scheme TodoLite-macOS -destination 'platform=macOS'
```

### Run Tests
```bash
xcodebuild -project TodoLite.xcodeproj -scheme TodoLite-iOS -destination 'platform=iOS Simulator,name=iPhone 16' test
```

### Targets (from project.yml)
- `TodoLite-iOS` — iOS app (deployment target 17.0)
- `TodoLite-macOS` — macOS app (deployment target 14.0)
- `TodoLiteWidget` — iOS widget extension
- `TodoLiteTests` — Unit tests

## Architecture

### Data Flow (strict)
```
View → TodoStore (Observable) → Repository (actor) → FileSystemManager (actor) → JSON files
```
Views must never touch `FileSystemManager` directly. All file operations go through `TodoStore` or the Repository layer.

### Key Components

| Layer | File(s) | Role |
|-------|---------|------|
| State | `Shared/Store/TodoStore.swift` | `@Observable` singleton. Holds `todos`, `projects`, `tags`. All CRUD is async and updates the store after repository confirms success. |
| Repository | `Shared/Repository/TodoRepository.swift`, `ProjectRepository.swift`, `TagRepository.swift` | `actor` singletons. Handle version-check conflict detection before writes. |
| File System | `Shared/FileSystem/FileSystemManager.swift` | `actor` singleton. Uses `NSFileCoordinator` for reads/writes/deletes. Falls back to local `documentDirectory` if iCloud unavailable. |
| Sync | `Shared/FileSystem/iCloudSyncManager.swift` | `NSMetadataQuery` listens for iCloud file changes and merges into `TodoStore` by version. |
| Search | `Shared/Search/SearchIndexer.swift` | SQLite FTS5 index. `TodoStore` calls `indexer.rebuild/index/remove` on data changes. |
| Parser | `Shared/Parser/TodoParser.swift`, `DateResolver.swift` | Rule-based (not AI) quick-entry parser. Syntax: `@project`, `#tag`, `!priority`, `^date`. |

### Conflict Resolution
Repositories check `version` before writing. If incoming version is not greater than existing, a conflict backup is written to `conflicts/` and `FileSystemError.conflictDetected` is thrown. iCloud sync merges by version number (`iCloudSyncManager`.

### Today Logic
`TodoStore.isToday(_:now:)` determines membership. A todo appears in Today if:
- Not done/archived, AND
- `isPinnedToday == true`, OR `scheduledAt` is today, OR `dueAt` <= now

Today sort order: pinned first, then by priority (high > medium > low), then by createdAt ascending.

### Status Mapping (Codable Migration)
Deprecated statuses are remapped during JSON decode:
- `next` → `doing`
- `blocked` → `waiting`
- `someday` → `waiting`
- `cancelled` → `archived`

### File Structure on Disk
```
iCloud Drive/TodoLite/
  tasks/task_<id>.json
  projects/project_<id>.json
  tags/tag_<id>.json
  trash/
  archive/
  conflicts/
  meta/
```

## Testing Conventions

Tests are in `Tests/TodoLiteTests.swift`. They import `@testable import TodoLite` and test:
- Model Codable round-trips
- Parser edge cases (empty input, emoji, multiple spaces, case insensitivity)
- `DateResolver` edge cases (weekend, year boundary, weekday-from-today)
- `TodoStore` derived collections (`todayTodos`, `activeTodos`, `inboxTodos`) and sort order
- Status codable migration from legacy JSON strings

## UI Structure

- **iOS**: `TabView` with tabs: Today, Inbox, Board, Search, Settings
- **macOS**: `NavigationSplitView` with Sidebar → detail. Includes `MenuBarExtra`. Keyboard shortcuts: ⌘1 Today, ⌘2 Inbox, ⌘3 Board, ⌘K Search.

## Important Rules

1. **File system is the source of truth.** Never treat SQLite or memory as authoritative.
2. **UI never touches files directly.** Always go through `TodoStore` → Repository.
3. **Sync layer is decoupled from business logic.** `iCloudSyncManager` only updates `TodoStore`; it does not trigger side effects.
4. **No AI in the write path.** Quick entry uses `TodoParser` (rule-based), not LLM.
5. **Data loss prevention > everything.** All writes are atomic (`Data.write(options: .atomic)`), conflict backups are preserved, and version numbers are incremented on every save.
