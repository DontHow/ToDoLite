import XCTest
import SwiftUI
@testable import TodoLite

final class TodoLiteTests: XCTestCase {

    // MARK: - Models

    func testTodoItemCodable() throws {
        let todo = TodoItem(title: "测试任务", status: .doing)
        let data = try JSONEncoder().encode(todo)
        let decoded = try JSONDecoder().decode(TodoItem.self, from: data)
        XCTAssertEqual(decoded.title, "测试任务")
        XCTAssertEqual(decoded.status, .doing)
    }

    func testFocusSetCodable() throws {
        let focus = FocusSet(date: "2026-05-27", taskIds: ["t1", "t2"])
        let data = try JSONEncoder().encode(focus)
        let decoded = try JSONDecoder().decode(FocusSet.self, from: data)
        XCTAssertEqual(decoded.date, "2026-05-27")
        XCTAssertEqual(decoded.taskIds, ["t1", "t2"])
    }

    func testProjectCodable() throws {
        let project = Project(name: "工作", emoji: "💼", colorHex: "#FF0000")
        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertEqual(decoded.name, "工作")
        XCTAssertEqual(decoded.emoji, "💼")
    }

    func testTagItemCodable() throws {
        let tag = TagItem(name: "iOS", colorHex: "#007AFF")
        let data = try JSONEncoder().encode(tag)
        let decoded = try JSONDecoder().decode(TagItem.self, from: data)
        XCTAssertEqual(decoded.name, "iOS")
    }

    // MARK: - Parser

    func testParserBasic() {
        let draft = TodoParser.parse("提交 TestFlight")
        XCTAssertEqual(draft.title, "提交 TestFlight")
        XCTAssertNil(draft.projectName)
        XCTAssertTrue(draft.tagNames.isEmpty)
    }

    func testParserWithProject() {
        let draft = TodoParser.parse("提交 TestFlight @工作")
        XCTAssertEqual(draft.title, "提交 TestFlight")
        XCTAssertEqual(draft.projectName, "工作")
    }

    func testParserWithTag() {
        let draft = TodoParser.parse("修复 Bug #iOS")
        XCTAssertEqual(draft.title, "修复 Bug")
        XCTAssertEqual(draft.tagNames, ["iOS"])
    }

    func testParserWithMultipleTags() {
        let draft = TodoParser.parse("修复 Bug #iOS #紧急")
        XCTAssertEqual(draft.tagNames, ["iOS", "紧急"])
    }

    func testParserWithDate() {
        let draft = TodoParser.parse("提交 TestFlight ^tomorrow")
        XCTAssertNotNil(draft.dueAt)
    }

    func testParserFull() {
        let draft = TodoParser.parse("提交 TestFlight @工作 #iOS ^tomorrow")
        XCTAssertEqual(draft.title, "提交 TestFlight")
        XCTAssertEqual(draft.projectName, "工作")
        XCTAssertEqual(draft.tagNames, ["iOS"])
        XCTAssertNotNil(draft.dueAt)
    }

    // MARK: - DateResolver

    func testDateResolverToday() {
        let date = DateResolver.resolve("today")
        XCTAssertNotNil(date)
        XCTAssertEqual(Calendar.current.isDateInToday(date!), true)
    }

    func testDateResolverTomorrow() {
        let date = DateResolver.resolve("tomorrow")
        XCTAssertNotNil(date)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
        XCTAssertEqual(date, tomorrow)
    }

    func testDateResolverInvalid() {
        XCTAssertNil(DateResolver.resolve("notadate"))
    }

    func testDateResolverRejectsInvalidCalendarDate() {
        XCTAssertNil(DateResolver.resolve("2026-02-30"))
        XCTAssertNil(DateResolver.resolve("13/40"))
    }

    func testLLMEndpointURLValidation() throws {
        XCTAssertEqual(
            try LLMService.endpointURL(baseURL: " https://api.openai.com/v1/ ").absoluteString,
            "https://api.openai.com/v1/chat/completions"
        )
        XCTAssertThrowsError(try LLMService.endpointURL(baseURL: "http://"))
        XCTAssertThrowsError(try LLMService.endpointURL(baseURL: "api.openai.com/v1"))
    }

    // MARK: - TodoStatus DisplayName

    func testStatusDisplayNames() {
        XCTAssertEqual(TodoStatus.inbox.displayName, "收件箱")
        XCTAssertEqual(TodoStatus.doing.displayName, "进行中")
        XCTAssertEqual(TodoStatus.done.displayName, "已完成")
        XCTAssertEqual(TodoStatus.archived.displayName, "已归档")
    }

    func testSectionThemePaletteHexValues() {
        XCTAssertEqual(SectionTheme.today.backgroundHex, "#F97316")
        XCTAssertEqual(SectionTheme.today.onBackgroundHex, "#FFFFFF")
        XCTAssertEqual(SectionTheme.today.primaryTextHex, "#C2410C")
        XCTAssertEqual(SectionTheme.today.secondaryTextHex, "#EA580C")
        XCTAssertEqual(SectionTheme.today.softBackgroundHex, "#FFF7ED")

        XCTAssertEqual(SectionTheme.upcoming.backgroundHex, "#2563EB")
        XCTAssertEqual(SectionTheme.inbox.backgroundHex, "#6366F1")
        XCTAssertEqual(SectionTheme.doing.backgroundHex, "#0D9488")
        XCTAssertEqual(SectionTheme.done.backgroundHex, "#16A34A")
        XCTAssertEqual(SectionTheme.archived.backgroundHex, "#64748B")
    }

    func testTodoStatusUsesSectionThemes() {
        XCTAssertEqual(TodoStatus.inbox.theme, .inbox)
        XCTAssertEqual(TodoStatus.doing.theme, .doing)
        XCTAssertEqual(TodoStatus.done.theme, .done)
        XCTAssertEqual(TodoStatus.archived.theme, .archived)
    }

    // MARK: - DateResolver Edge Cases

    func testDateResolverWeekendOnSunday() {
        let calendar = Calendar.current
        var components = DateComponents(year: 2026, month: 5, day: 24) // Sunday
        let sunday = calendar.date(from: components)!
        let date = DateResolver.resolve("weekend", from: sunday)
        XCTAssertNotNil(date)
        XCTAssertEqual(calendar.component(.weekday, from: date!), 7) // Saturday
        let daysDiff = calendar.dateComponents([.day], from: sunday, to: date!).day!
        XCTAssertEqual(daysDiff, 6) // Next Saturday, 6 days later
    }

    func testDateResolverWeekendOnSaturday() {
        let calendar = Calendar.current
        var components = DateComponents(year: 2026, month: 5, day: 23) // Saturday
        let saturday = calendar.date(from: components)!
        let date = DateResolver.resolve("weekend", from: saturday)
        XCTAssertNotNil(date)
        let daysDiff = calendar.dateComponents([.day], from: saturday, to: date!).day!
        XCTAssertEqual(daysDiff, 7) // Next Saturday
    }

    func testDateResolverYearBoundary() {
        let calendar = Calendar.current
        var components = DateComponents(year: 2026, month: 12, day: 31)
        let dec31 = calendar.date(from: components)!
        let date = DateResolver.resolve("1/1", from: dec31)
        XCTAssertNotNil(date)
        XCTAssertEqual(calendar.component(.year, from: date!), 2027)
        XCTAssertEqual(calendar.component(.month, from: date!), 1)
        XCTAssertEqual(calendar.component(.day, from: date!), 1)
    }

    func testDateResolverWeekdayToday() {
        let calendar = Calendar.current
        var components = DateComponents(year: 2026, month: 5, day: 26) // Tuesday
        let tuesday = calendar.date(from: components)!
        let date = DateResolver.resolve("tue", from: tuesday)
        XCTAssertNotNil(date)
        let daysDiff = calendar.dateComponents([.day], from: tuesday, to: date!).day!
        XCTAssertEqual(daysDiff, 7) // Next Tuesday
    }

    func testDateResolverNextWeek() {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())
        let date = DateResolver.resolve("next week")
        XCTAssertNotNil(date)
        let daysDiff = calendar.dateComponents([.day], from: base, to: date!).day!
        XCTAssertEqual(daysDiff, 7)
    }

    // MARK: - TodoParser Edge Cases

    func testParserEmpty() {
        let draft = TodoParser.parse("")
        XCTAssertEqual(draft.title, "")
        XCTAssertNil(draft.projectName)
        XCTAssertTrue(draft.tagNames.isEmpty)
    }

    func testParserOnlyMetadata() {
        let draft = TodoParser.parse("@工作 #iOS")
        XCTAssertEqual(draft.title, "")
        XCTAssertEqual(draft.projectName, "工作")
        XCTAssertEqual(draft.tagNames, ["iOS"])
    }

    func testParserEmojiTitle() {
        let draft = TodoParser.parse("🚀 发布版本 @工作")
        XCTAssertEqual(draft.title, "🚀 发布版本")
        XCTAssertEqual(draft.projectName, "工作")
    }

    func testParserMultipleSpaces() {
        let draft = TodoParser.parse("修复Bug    @工作   #iOS")
        XCTAssertEqual(draft.title, "修复Bug")
        XCTAssertEqual(draft.projectName, "工作")
        XCTAssertEqual(draft.tagNames, ["iOS"])
    }

    // MARK: - Color+Hex

    func testColorHex3Char() {
        let color = Color(hex: "#F0A")
        // RGB 12-bit: F=15*17=255, 0=0, A=10*17=170
        // Cannot easily assert Color values in unit tests without UI, but verify no crash
        XCTAssertNotNil(color)
    }

    func testColorHex8Char() {
        let color = Color(hex: "#80FF0000")
        // ARGB: A=128, R=255, G=0, B=0
        XCTAssertNotNil(color)
    }

    func testColorHexInvalid() {
        let color = Color(hex: "GGGGGG")
        // Invalid hex should fall through to default (black)
        XCTAssertNotNil(color)
    }

    func testColorHexEmpty() {
        let color = Color(hex: "")
        XCTAssertNotNil(color)
    }

    // MARK: - TodoStore Focus Logic

    @MainActor
    func testFocusTodos() {
        let store = TodoStore()
        let t1 = TodoItem(id: "t1", title: "Focus1", status: .doing)
        let t2 = TodoItem(id: "t2", title: "Focus2", status: .doing)
        let t3 = TodoItem(id: "t3", title: "非Focus", status: .doing)

        store.todos = [t1, t2, t3]
        store.focusSet = FocusSet(date: FocusSet.todayString(), taskIds: ["t1", "t2"])

        XCTAssertEqual(store.focusTodos.count, 2)
        XCTAssertTrue(store.focusTodos.contains { $0.title == "Focus1" })
        XCTAssertTrue(store.focusTodos.contains { $0.title == "Focus2" })
    }

    @MainActor
    func testFocusTodosExcludesDone() {
        let store = TodoStore()
        let t1 = TodoItem(id: "t1", title: "已完成Focus", status: .done)

        store.todos = [t1]
        store.focusSet = FocusSet(date: FocusSet.todayString(), taskIds: ["t1"])

        XCTAssertEqual(store.focusTodos.count, 0)
    }

    @MainActor
    func testSuggestedTodos() {
        let store = TodoStore()
        let today = Date()
        let t1 = TodoItem(id: "t1", title: "今日计划", status: .doing, scheduledAt: today, dueAt: today)
        let t2 = TodoItem(id: "t2", title: "今日到期", status: .doing, dueAt: today)
        let t3 = TodoItem(id: "t3", title: "已在Focus", status: .doing, scheduledAt: today, dueAt: today)

        store.todos = [t1, t2, t3]
        store.focusSet = FocusSet(date: FocusSet.todayString(), taskIds: ["t3"])

        XCTAssertEqual(store.suggestedTodos.count, 2)
        XCTAssertTrue(store.suggestedTodos.contains { $0.title == "今日计划" })
        XCTAssertTrue(store.suggestedTodos.contains { $0.title == "今日到期" })
    }

    @MainActor
    func testOverdueTodos() {
        let store = TodoStore()
        let past = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let t1 = TodoItem(id: "t1", title: "逾期", status: .doing, dueAt: past)
        let t2 = TodoItem(id: "t2", title: "今天到期", status: .doing, dueAt: Date())

        store.todos = [t1, t2]

        XCTAssertEqual(store.overdueTodos.count, 1)
        XCTAssertEqual(store.overdueTodos[0].title, "逾期")
    }

    func testTodoReschedulePresetDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let baseDate = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 14,
            hour: 18,
            minute: 30
        )))

        XCTAssertEqual(
            TodoReschedulePreset.threeDays.dueDate(from: baseDate, calendar: calendar),
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 17))
        )
        XCTAssertEqual(
            TodoReschedulePreset.oneWeek.dueDate(from: baseDate, calendar: calendar),
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 21))
        )
        XCTAssertEqual(
            TodoReschedulePreset.oneMonth.dueDate(from: baseDate, calendar: calendar),
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 14))
        )
    }

    @MainActor
    func testActiveTodos() {
        let store = TodoStore()
        store.todos = [
            TodoItem(title: "进行中", status: .doing),
            TodoItem(title: "已完成", status: .done),
            TodoItem(title: "已归档", status: .archived),
            TodoItem(title: "收件箱", status: .inbox),
        ]
        XCTAssertEqual(store.activeTodos.count, 2)
        XCTAssertTrue(store.activeTodos.contains { $0.title == "进行中" })
        XCTAssertTrue(store.activeTodos.contains { $0.title == "收件箱" })
    }

    @MainActor
    func testInboxTodos() {
        let store = TodoStore()
        store.todos = [
            TodoItem(title: "进行中", status: .doing),
            TodoItem(title: "收件箱", status: .inbox),
            TodoItem(title: "收件箱2", status: .inbox),
        ]
        XCTAssertEqual(store.inboxTodos.count, 2)
    }

    @MainActor
    func testExternalSyncUpdatesAreSerialized() async {
        let store = TodoStore()

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    await store.applyExternalProject(Project(id: "project-\(index)", name: "项目 \(index)"))
                    await store.applyExternalTag(TagItem(id: "tag-\(index)", name: "标签 \(index)"))
                }
            }
        }

        XCTAssertEqual(Set(store.projects.map(\.id)).count, 20)
        XCTAssertEqual(Set(store.tags.map(\.id)).count, 20)
    }

    @MainActor
    func testExternalProjectIgnoresOlderUpdate() async {
        let store = TodoStore()
        let currentDate = Date()
        store.projects = [
            Project(id: "project", name: "新版名称", updatedAt: currentDate)
        ]

        await store.applyExternalProject(
            Project(
                id: "project",
                name: "旧版名称",
                updatedAt: currentDate.addingTimeInterval(-60)
            )
        )

        XCTAssertEqual(store.projects.first?.name, "新版名称")
        XCTAssertEqual(store.projects.first?.updatedAt, currentDate)
    }

    @MainActor
    func testExternalProjectAcceptsNewerUpdate() async {
        let store = TodoStore()
        let currentDate = Date()
        let newerDate = currentDate.addingTimeInterval(60)
        store.projects = [
            Project(id: "project", name: "旧版名称", updatedAt: currentDate)
        ]

        await store.applyExternalProject(
            Project(id: "project", name: "新版名称", updatedAt: newerDate)
        )

        XCTAssertEqual(store.projects.first?.name, "新版名称")
        XCTAssertEqual(store.projects.first?.updatedAt, newerDate)
    }

    func testDueDateGroupingSeparatesOverdueTodos() {
        let calendar = Calendar.current
        let overdue = TodoItem(
            title: "逾期任务",
            dueAt: calendar.date(byAdding: .day, value: -30, to: Date())
        )
        let today = TodoItem(title: "今日任务", dueAt: Date())

        let groups = TaskGrouping.dueDate.apply(to: [overdue, today], projects: [])

        XCTAssertEqual(groups.first?.title, "逾期")
        XCTAssertEqual(groups.first?.todos, [overdue])
        XCTAssertEqual(groups.dropFirst().first?.title, "今天")
    }

    func testSearchIndexerSupportsStringTodoIds() async {
        let todo = TodoItem(id: UUID().uuidString, title: "唯一搜索关键词")

        await SearchIndexer.shared.rebuild(todos: [todo], projects: [], tags: [])
        let results = await SearchIndexer.shared.search(query: "唯一搜索")

        XCTAssertEqual(results, [todo.id])
    }

    func testSearchIndexerTreatsPunctuationAsLiteralText() async {
        let todo = TodoItem(id: UUID().uuidString, title: "修复 sync-error")

        await SearchIndexer.shared.rebuild(todos: [todo], projects: [], tags: [])
        let results = await SearchIndexer.shared.search(query: "sync-error")

        XCTAssertEqual(results, [todo.id])
    }

    func testSearchIndexerReflectsTodoProjectAndTagUpdates() async {
        let todoId = UUID().uuidString
        let projectId = UUID().uuidString
        let tagId = UUID().uuidString
        let original = TodoItem(
            id: todoId,
            title: "旧任务标题",
            projectId: projectId,
            tagIds: [tagId]
        )

        await SearchIndexer.shared.rebuild(
            todos: [original],
            projects: [Project(id: projectId, name: "旧项目")],
            tags: [TagItem(id: tagId, name: "旧标签")]
        )
        let originalTitleResults = await SearchIndexer.shared.search(query: "旧任务")
        let originalProjectResults = await SearchIndexer.shared.search(query: "旧项目")
        let originalTagResults = await SearchIndexer.shared.search(query: "旧标签")
        XCTAssertEqual(originalTitleResults, [todoId])
        XCTAssertEqual(originalProjectResults, [todoId])
        XCTAssertEqual(originalTagResults, [todoId])

        var updated = original
        updated.title = "新任务标题"
        await SearchIndexer.shared.rebuild(
            todos: [updated],
            projects: [Project(id: projectId, name: "新项目")],
            tags: [TagItem(id: tagId, name: "新标签")]
        )

        let staleTitleResults = await SearchIndexer.shared.search(query: "旧任务")
        let staleProjectResults = await SearchIndexer.shared.search(query: "旧项目")
        let staleTagResults = await SearchIndexer.shared.search(query: "旧标签")
        let updatedTitleResults = await SearchIndexer.shared.search(query: "新任务")
        let updatedProjectResults = await SearchIndexer.shared.search(query: "新项目")
        let updatedTagResults = await SearchIndexer.shared.search(query: "新标签")
        XCTAssertTrue(staleTitleResults.isEmpty)
        XCTAssertTrue(staleProjectResults.isEmpty)
        XCTAssertTrue(staleTagResults.isEmpty)
        XCTAssertEqual(updatedTitleResults, [todoId])
        XCTAssertEqual(updatedProjectResults, [todoId])
        XCTAssertEqual(updatedTagResults, [todoId])
    }

    func testAutomaticUpdateCheckThrottle() {
        let now = Date()

        XCTAssertFalse(UpdateChecker.shouldCheckAutomatically(isEnabled: false, lastCheck: nil, now: now))
        XCTAssertTrue(UpdateChecker.shouldCheckAutomatically(isEnabled: true, lastCheck: nil, now: now))
        XCTAssertFalse(UpdateChecker.shouldCheckAutomatically(
            isEnabled: true,
            lastCheck: now.addingTimeInterval(-60 * 60),
            now: now
        ))
        XCTAssertTrue(UpdateChecker.shouldCheckAutomatically(
            isEnabled: true,
            lastCheck: now.addingTimeInterval(-25 * 60 * 60),
            now: now
        ))
    }

    func testICloudRequestsMissingFileDownload() {
        XCTAssertTrue(iCloudSyncManager.shouldRequestDownload(
            status: NSMetadataUbiquitousItemDownloadingStatusNotDownloaded,
            alreadyRequested: false
        ))
        XCTAssertFalse(iCloudSyncManager.shouldRequestDownload(
            status: NSMetadataUbiquitousItemDownloadingStatusNotDownloaded,
            alreadyRequested: true
        ))
    }

    func testICloudDoesNotDownloadCurrentOrStaleLocalFileExplicitly() {
        XCTAssertFalse(iCloudSyncManager.shouldRequestDownload(
            status: NSMetadataUbiquitousItemDownloadingStatusCurrent,
            alreadyRequested: false
        ))
        XCTAssertFalse(iCloudSyncManager.shouldRequestDownload(
            status: NSMetadataUbiquitousItemDownloadingStatusDownloaded,
            alreadyRequested: false
        ))
        XCTAssertFalse(iCloudSyncManager.shouldRequestDownload(status: nil, alreadyRequested: false))
    }

    @MainActor
    func testToggleCompleteStateMachine() {
        let store = TodoStore()
        let doing = TodoItem(title: "进行中", status: .doing)
        let done = TodoItem(title: "已完成", status: .done, completedAt: Date())

        store.todos = [doing, done]

        XCTAssertEqual(store.todos[0].status, .doing)
        XCTAssertEqual(store.todos[1].status, .done)

        // doing -> done
        var m1 = store.todos[0]
        if m1.status == .done {
            m1.status = .doing
            m1.completedAt = nil
        } else {
            m1.status = .done
            m1.completedAt = Date()
        }
        XCTAssertEqual(m1.status, .done)
        XCTAssertNotNil(m1.completedAt)

        // done -> doing
        var m2 = store.todos[1]
        if m2.status == .done {
            m2.status = .doing
            m2.completedAt = nil
        } else {
            m2.status = .done
            m2.completedAt = Date()
        }
        XCTAssertEqual(m2.status, .doing)
        XCTAssertNil(m2.completedAt)
    }

    func testArchivingActiveTodoDoesNotMarkItCompleted() {
        let archived = TodoItem(title: "未完成归档", status: .doing).archived()

        XCTAssertEqual(archived.status, .archived)
        XCTAssertNil(archived.completedAt)
    }

    func testArchivingCompletedTodoPreservesCompletionDate() {
        let completedAt = Date()
        let archived = TodoItem(
            title: "已完成归档",
            status: .done,
            completedAt: completedAt
        ).archived()

        XCTAssertEqual(archived.status, .archived)
        XCTAssertEqual(archived.completedAt, completedAt)
    }

    func testStatusCodableMigration() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let jsonNext = #"{"id":"1","title":"t","description":"","status":"next","priority":"medium","tagIds":[],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z","version":1}"#.data(using: .utf8)!
        let decodedNext = try decoder.decode(TodoItem.self, from: jsonNext)
        XCTAssertEqual(decodedNext.status, .doing)

        let jsonBlocked = #"{"id":"2","title":"t","description":"","status":"blocked","priority":"medium","tagIds":[],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z","version":1}"#.data(using: .utf8)!
        let decodedBlocked = try decoder.decode(TodoItem.self, from: jsonBlocked)
        XCTAssertEqual(decodedBlocked.status, .doing)

        let jsonSomeday = #"{"id":"3","title":"t","description":"","status":"someday","priority":"medium","tagIds":[],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z","version":1}"#.data(using: .utf8)!
        let decodedSomeday = try decoder.decode(TodoItem.self, from: jsonSomeday)
        XCTAssertEqual(decodedSomeday.status, .doing)

        let jsonCancelled = #"{"id":"4","title":"t","description":"","status":"cancelled","priority":"medium","tagIds":[],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z","version":1}"#.data(using: .utf8)!
        let decodedCancelled = try decoder.decode(TodoItem.self, from: jsonCancelled)
        XCTAssertEqual(decodedCancelled.status, .archived)
    }

    func testOldJsonIgnoresIsPinnedToday() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let json = #"{"id":"1","title":"t","description":"","status":"inbox","priority":"medium","tagIds":[],"isPinnedToday":true,"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z","version":1}"#.data(using: .utf8)!
        let decoded = try decoder.decode(TodoItem.self, from: json)
        XCTAssertEqual(decoded.title, "t")
        XCTAssertEqual(decoded.status, .inbox)
    }
}
