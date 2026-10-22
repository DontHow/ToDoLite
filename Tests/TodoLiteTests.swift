import XCTest
import SwiftUI
import Security
import SQLite3
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

    func testLLMConfigCodable() throws {
        let config = LLMConfig(apiKey: "sk-test", baseURL: "https://api.deepseek.com", model: "deepseek-v4-flash", reportTemplate: "自定义模板")
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LLMConfig.self, from: data)
        XCTAssertEqual(decoded.apiKey, "")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["apiKey"])
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("sk-test"))
        XCTAssertEqual(decoded.reportTemplate, "自定义模板")
    }

    func testLLMConfigDecodesLegacyJSONWithoutReportTemplate() throws {
        // 旧版本配置没有 reportTemplate 字段，应回退为空串
        let legacy = #"{"apiKey":"sk-old","baseURL":"https://api.openai.com/v1","model":"gpt-4o-mini"}"#
        let decoded = try JSONDecoder().decode(LLMConfig.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.apiKey, "sk-old")
        XCTAssertEqual(decoded.model, "gpt-4o-mini")
        XCTAssertEqual(decoded.reportTemplate, "")
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

    func testTaskGroupingUsesStableIds() {
        let todo = TodoItem(title: "任务", dueAt: Date())

        let firstIds = TaskGrouping.dueDate.apply(to: [todo], projects: []).map(\.id)
        let secondIds = TaskGrouping.dueDate.apply(to: [todo], projects: []).map(\.id)

        XCTAssertEqual(firstIds, secondIds)
    }

    func testProjectGroupingIdsDoNotDependOnDuplicateNames() {
        let projects = [
            Project(id: "one", name: "同名项目"),
            Project(id: "two", name: "同名项目"),
        ]
        let todos = [
            TodoItem(title: "任务一", projectId: "one"),
            TodoItem(title: "任务二", projectId: "two"),
        ]

        let groups = TaskGrouping.byProject.apply(to: todos, projects: projects)

        XCTAssertEqual(Set(groups.map(\.id)), Set(["project-one", "project-two"]))
    }

    func testProjectGroupingSortsProjectsByNearestDueDate() {
        let now = Date()
        let projects = [
            Project(id: "later", name: "稍后项目"),
            Project(id: "none", name: "无截止项目"),
            Project(id: "sooner", name: "近期项目"),
        ]
        let todos = [
            TodoItem(title: "稍后任务", projectId: "later", dueAt: now.addingTimeInterval(2 * 86_400)),
            TodoItem(title: "无截止任务", projectId: "none"),
            TodoItem(title: "近期任务", projectId: "sooner", dueAt: now.addingTimeInterval(86_400)),
            TodoItem(title: "近期项目的远期任务", projectId: "sooner", dueAt: now.addingTimeInterval(3 * 86_400)),
        ]

        let groups = TaskGrouping.byProject.apply(to: todos, projects: projects)

        XCTAssertEqual(groups.map(\.id), ["project-sooner", "project-later", "project-none"])
    }

    func testSearchIndexerSupportsStringTodoIds() async throws {
        let todo = TodoItem(id: UUID().uuidString, title: "唯一搜索关键词")

        await SearchIndexer.shared.rebuild(todos: [todo], projects: [], tags: [])
        let results = try await SearchIndexer.shared.search(query: "唯一搜索")

        XCTAssertEqual(results, [todo.id])
    }

    func testSearchIndexerTreatsPunctuationAsLiteralText() async throws {
        let todo = TodoItem(id: UUID().uuidString, title: "修复 sync-error")

        await SearchIndexer.shared.rebuild(todos: [todo], projects: [], tags: [])
        let results = try await SearchIndexer.shared.search(query: "sync-error")

        XCTAssertEqual(results, [todo.id])
    }

    func testSearchIndexerReflectsTodoProjectAndTagUpdates() async throws {
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
        let originalTitleResults = try await SearchIndexer.shared.search(query: "旧任务")
        let originalProjectResults = try await SearchIndexer.shared.search(query: "旧项目")
        let originalTagResults = try await SearchIndexer.shared.search(query: "旧标签")
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

        let staleTitleResults = try await SearchIndexer.shared.search(query: "旧任务")
        let staleProjectResults = try await SearchIndexer.shared.search(query: "旧项目")
        let staleTagResults = try await SearchIndexer.shared.search(query: "旧标签")
        let updatedTitleResults = try await SearchIndexer.shared.search(query: "新任务")
        let updatedProjectResults = try await SearchIndexer.shared.search(query: "新项目")
        let updatedTagResults = try await SearchIndexer.shared.search(query: "新标签")
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

    func testICloudOnlyRemovesItemsThatRemainAbsent() {
        XCTAssertFalse(iCloudSyncManager.shouldRemoveExternalItem(fileExists: true))
        XCTAssertTrue(iCloudSyncManager.shouldRemoveExternalItem(fileExists: false))
    }

    @MainActor
    func testToggleCompleteStateMachine() async throws {
        let (fs, _) = try await makeTestFileSystem()
        let store = TodoStore(fs: fs, keyStorage: MemoryAPIKeyStorage())
        try await store.createTodo(title: "进行中", status: .doing)
        let id = try XCTUnwrap(store.todos.first?.id)
        try await store.toggleComplete(id: id)
        XCTAssertEqual(store.todos.first?.status, .done)
        XCTAssertNotNil(store.todos.first?.completedAt)
        let persisted = try await TodoRepository(fs: fs).read(id: id)
        XCTAssertEqual(persisted.status, .done)
        XCTAssertNotNil(persisted.completedAt)

        try await store.toggleComplete(id: id)
        XCTAssertEqual(store.todos.first?.status, .doing)
        XCTAssertNil(store.todos.first?.completedAt)
        let reopened = try await TodoRepository(fs: fs).read(id: id)
        XCTAssertNil(reopened.completedAt)
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
    // MARK: - Persistence Reliability

    private func makeTestFileSystem() async throws -> (FileSystemManager, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let fs = FileSystemManager(documentsURL: root)
        try await fs.setupDirectories()
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (fs, root.appendingPathComponent("TodoLite"))
    }

    func testConcurrentSavesRejectOneEditAndKeepBackup() async throws {
        let (fs, appRoot) = try await makeTestFileSystem()
        let firstRepo = TodoRepository(fs: fs)
        // 独立 Repository 和文件系统 actor 共用目录，验证文件协调而非 actor 串行执行。
        let secondFS = FileSystemManager(documentsURL: appRoot.deletingLastPathComponent())
        let secondRepo = TodoRepository(fs: secondFS)
        let original = try await firstRepo.create(TodoItem(title: "原任务"))
        let outcomes = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for index in 0..<2 {
                group.addTask {
                    var edit = original
                    edit.title = "编辑 \(index)"
                    do {
                        _ = try await (index == 0 ? firstRepo : secondRepo).save(edit)
                        return true
                    } catch {
                        return false
                    }
                }
            }
            var results: [Bool] = []
            for await result in group { results.append(result) }
            return results
        }
        XCTAssertEqual(outcomes.filter { $0 }.count, 1)
        let saved = try await firstRepo.read(id: original.id)
        XCTAssertEqual(saved.version, original.version + 1)
        let backups = try await fs.listFiles(in: .conflicts)
        XCTAssertEqual(backups.count, 1)
        let rejected = try await fs.read(TodoItem.self, filename: XCTUnwrap(backups.first), directory: .conflicts)
        XCTAssertNotEqual(rejected.title, saved.title)
        XCTAssertEqual(rejected.version, original.version)
    }

    func testSavingFutureVersionIsRejected() async throws {
        let (fs, _) = try await makeTestFileSystem()
        let repo = TodoRepository(fs: fs)
        let original = try await repo.create(TodoItem(title: "原任务"))
        var edit = original
        edit.version += 10
        do {
            _ = try await repo.save(edit)
            XCTFail("不应接受未匹配的版本")
        } catch {
            XCTAssertEqual(error as? FileSystemError, .conflictDetected)
        }
        let saved = try await repo.read(id: original.id)
        XCTAssertEqual(saved, original)
    }

    func testCorruptTodoIsNeverOverwritten() async throws {
        let (fs, root) = try await makeTestFileSystem()
        let repo = TodoRepository(fs: fs)
        let original = try await repo.create(TodoItem(title: "原任务"))
        let file = root.appendingPathComponent("tasks/task_\(original.id).json")
        let damaged = Data("{broken json".utf8)
        try damaged.write(to: file)
        do {
            _ = try await repo.save(original)
            XCTFail("损坏文件不得被覆盖")
        } catch {
            XCTAssertEqual(error as? FileSystemError, .invalidFile(file.lastPathComponent))
        }
        XCTAssertEqual(try Data(contentsOf: file), damaged)
        do {
            _ = try await repo.listAll()
            XCTFail("加载失败不得静默跳过")
        } catch {
            XCTAssertEqual(error as? FileSystemError, .invalidFile(file.lastPathComponent))
        }
    }

    func testDeletedTodoCannotBeRecreatedByStaleEditor() async throws {
        let (fs, _) = try await makeTestFileSystem()
        let repo = TodoRepository(fs: fs)
        let original = try await repo.create(TodoItem(title: "任务"))
        try await repo.delete(id: original.id)
        do {
            _ = try await repo.save(original)
            XCTFail("旧编辑不能恢复已删除任务")
        } catch {
            XCTAssertEqual(error as? FileSystemError, .fileNotFound("task_\(original.id).json"))
        }
        let tasks = try await repo.listAll()
        XCTAssertTrue(tasks.isEmpty)
    }

    func testCreatingExistingTodoIsRejected() async throws {
        let (fs, _) = try await makeTestFileSystem()
        let repo = TodoRepository(fs: fs)
        let original = TodoItem(title: "任务")
        _ = try await repo.create(original)
        do {
            _ = try await repo.create(original)
            XCTFail("重复创建不能覆盖旧任务")
        } catch {
            XCTAssertEqual(error as? FileSystemError, .conflictDetected)
        }
    }

    @MainActor
    func testFormStyleStatusUpdatesNormalizeCompletionAndPersist() async throws {
        let (fs, _) = try await makeTestFileSystem()
        let store = TodoStore(fs: fs, keyStorage: MemoryAPIKeyStorage())
        try await store.createTodo(title: "已完成的新任务", status: .done)
        var edit = try XCTUnwrap(store.todos.first)
        XCTAssertNotNil(edit.completedAt)
        let completionDate = edit.completedAt
        edit.title = "修改已完成标题"
        try await store.updateTodo(edit)
        XCTAssertEqual(store.todos.first?.completedAt, completionDate)
        edit = try XCTUnwrap(store.todos.first)
        edit.status = .inbox
        try await store.updateTodo(edit)
        XCTAssertNil(store.todos.first?.completedAt)
        edit = try XCTUnwrap(store.todos.first)
        edit.status = .done
        try await store.updateTodo(edit)
        let persisted = try await TodoRepository(fs: fs).read(id: edit.id)
        XCTAssertEqual(persisted.status, .done)
        XCTAssertNotNil(persisted.completedAt)
        try await store.changeStatus(id: edit.id, to: .doing)
        XCTAssertNil(store.todos.first?.completedAt)
    }

    @MainActor
    func testLoadFailurePreservesSnapshotAndCanRetry() async throws {
        let (fs, root) = try await makeTestFileSystem()
        let store = TodoStore(fs: fs, keyStorage: MemoryAPIKeyStorage())
        let existing = TodoItem(title: "内存原任务")
        store.todos = [existing]
        let corrupt = root.appendingPathComponent("projects/project_broken.json")
        try Data("bad json".utf8).write(to: corrupt)
        await store.initialize()
        guard case .failed(let message) = store.loadState else { return XCTFail("应显示加载失败") }
        XCTAssertTrue(message.contains("project_broken.json"))
        XCTAssertEqual(store.todos, [existing])
        try FileManager.default.removeItem(at: corrupt)
        await store.initialize()
        XCTAssertEqual(store.loadState, .loaded)
        XCTAssertTrue(store.todos.isEmpty)
    }

    func testMissingFocusDefaultsButCorruptFocusThrows() async throws {
        let (fs, root) = try await makeTestFileSystem()
        let repo = FocusRepository(fs: fs)
        let date = Date()
        let empty = try await repo.load(for: date)
        XCTAssertTrue(empty.taskIds.isEmpty)
        let filename = FocusRepository.filename(for: date)
        try Data("bad json".utf8).write(to: root.appendingPathComponent("meta/" + filename))
        do {
            _ = try await repo.load(for: date)
            XCTFail("损坏的关注文件不应返回空列表")
        } catch {
            XCTAssertEqual(error as? FileSystemError, .invalidFile(filename))
        }
    }

    func testLegacyAPIKeyMigratesBeforePlaintextIsRemoved() async throws {
        let (fs, root) = try await makeTestFileSystem()
        let configFile = root.appendingPathComponent("config/llm_config.json")
        try Data(#"{"apiKey":"legacy-test-key","model":"test-model"}"#.utf8).write(to: configFile)
        let keys = MemoryAPIKeyStorage()
        let repo = LLMConfigRepository(fs: fs, keyStorage: keys)
        let config = try await repo.loadOrDefault()
        XCTAssertEqual(config.apiKey, "legacy-test-key")
        XCTAssertEqual(try keys.load(), "legacy-test-key")
        let disk = try JSONSerialization.jsonObject(with: Data(contentsOf: configFile)) as? [String: Any]
        XCTAssertNil(disk?["apiKey"])
        XCTAssertEqual(disk?["model"] as? String, "test-model")
        let reloaded = try await repo.loadOrDefault()
        XCTAssertEqual(reloaded.apiKey, "legacy-test-key")
    }

    func testKeychainFailurePreservesLegacyPlaintextForRetry() async throws {
        let (fs, root) = try await makeTestFileSystem()
        let configFile = root.appendingPathComponent("config/llm_config.json")
        let legacy = Data(#"{"apiKey":"legacy-test-key"}"#.utf8)
        try legacy.write(to: configFile)
        let repo = LLMConfigRepository(fs: fs, keyStorage: UnavailableAPIKeyStorage())
        do {
            _ = try await repo.loadOrDefault()
            XCTFail("钥匙串失败必须可见")
        } catch {
            XCTAssertEqual(try Data(contentsOf: configFile), legacy)
        }
    }

    func testClearedLocalKeyIsNotRestoredFromLegacyCloudConfig() async throws {
        let (fs, root) = try await makeTestFileSystem()
        let file = root.appendingPathComponent("config/llm_config.json")
        try Data(#"{"apiKey":"old-cloud-key"}"#.utf8).write(to: file)
        let keys = MemoryAPIKeyStorage()
        try keys.save("")
        let repo = LLMConfigRepository(fs: fs, keyStorage: keys)
        let config = try await repo.loadOrDefault()
        XCTAssertEqual(config.apiKey, "")
        let disk = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        XCTAssertNil(disk?["apiKey"])
    }

    func testSavingConfigStoresKeyOnlyInKeyStorage() async throws {
        let (fs, _) = try await makeTestFileSystem()
        let keys = MemoryAPIKeyStorage()
        let repo = LLMConfigRepository(fs: fs, keyStorage: keys)
        try await repo.save(LLMConfig(apiKey: "local-only-key", model: "test-model"))
        XCTAssertEqual(try keys.load(), "local-only-key")
        let disk = try await fs.read(LLMConfig.self, filename: "llm_config.json", directory: .config)
        XCTAssertEqual(disk.apiKey, "")
        XCTAssertEqual(disk.model, "test-model")
        let loaded = try await repo.loadOrDefault()
        XCTAssertEqual(loaded.apiKey, "local-only-key")
    }

    func testKeychainStorageRoundTripAndClear() throws {
        let service = "com.donghao.TodoLite.tests." + UUID().uuidString
        let storage = KeychainAPIKeyStorage(service: service, account: "test-api-key")
        defer {
            SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                           kSecAttrService as String: service,
                           kSecAttrAccount as String: "test-api-key"] as CFDictionary)
        }
        XCTAssertNil(try storage.load())
        try storage.save("test-key-one")
        XCTAssertEqual(try storage.load(), "test-key-one")
        try storage.save("test-key-two")
        XCTAssertEqual(try storage.load(), "test-key-two")
        try storage.save("")
        XCTAssertEqual(try storage.load(), "")
    }

    func testCorruptLLMConfigDoesNotBecomeDefaultConfig() async throws {
        let (fs, root) = try await makeTestFileSystem()
        try Data("bad json".utf8).write(to: root.appendingPathComponent("config/llm_config.json"))
        let repo = LLMConfigRepository(fs: fs, keyStorage: MemoryAPIKeyStorage())
        do {
            _ = try await repo.loadOrDefault()
            XCTFail("损坏配置不应静默回退")
        } catch {
            XCTAssertEqual(error as? FileSystemError, .invalidFile("llm_config.json"))
        }
    }

    // MARK: - Chinese Search

    func testChineseSearchFindsMiddleAndSingleCharacters() async throws {
        let index = SearchIndexer(inMemory: true)
        let item = TodoItem(id: "task", title: "修复登录页面崩溃")
        await index.rebuild(todos: [item], projects: [], tags: [])
        for query in ["修复", "登录", "崩溃", "登", "登录 页面", "页面崩溃"] {
            let ids = try await index.search(query: query)
            XCTAssertEqual(ids, [item.id], query)
        }
        let nonAdjacent = try await index.search(query: "登溃")
        XCTAssertTrue(nonAdjacent.isEmpty)
    }

    func testChineseSearchMatchesMetadataAndMixedLanguage() async throws {
        let index = SearchIndexer(inMemory: true)
        let item = TodoItem(id: "task", title: "修复 iOS 登录", description: "处理用户权限异常", projectId: "p", tagIds: ["t"])
        await index.rebuild(todos: [item], projects: [Project(id: "p", name: "客户交付项目")], tags: [TagItem(id: "t", name: "高优先级")])
        for query in ["ios 登录", "权限", "交付", "优先", "用户 交付 优先"] {
            let ids = try await index.search(query: query)
            XCTAssertEqual(ids, [item.id], query)
        }
        let blank = try await index.search(query: "  \n ")
        XCTAssertTrue(blank.isEmpty)
    }

    func testSearchUpdatesAndRemovalsDoNotLeaveOldTerms() async throws {
        let index = SearchIndexer(inMemory: true)
        var item = TodoItem(id: "task", title: "处理登录异常")
        await index.rebuild(todos: [item], projects: [], tags: [])
        item.title = "处理支付异常"
        await index.index(todo: item, projects: [], tags: [])
        let old = try await index.search(query: "登录")
        let new = try await index.search(query: "支付")
        XCTAssertTrue(old.isEmpty)
        XCTAssertEqual(new, [item.id])
        await index.remove(todoId: item.id)
        let removed = try await index.search(query: "支付")
        XCTAssertTrue(removed.isEmpty)
    }

    func testSearchTreatsFTSOperatorsAsLiteralInput() async throws {
        let index = SearchIndexer(inMemory: true)
        let item = TodoItem(id: "literal", title: "登录 OR 修复 sync-error")
        await index.rebuild(todos: [item, TodoItem(id: "other", title: "登录")], projects: [], tags: [])
        let ids = try await index.search(query: "OR sync-error")
        XCTAssertEqual(ids, [item.id])
        let quoted = try await index.search(query: #""sync-error""#)
        XCTAssertEqual(quoted, [item.id])
    }

    // MARK: - Local/Cloud Merge

    private func makeMigrationFileSystems() async throws -> (FileSystemManager, URL, FileSystemManager, URL) {
        let (local, localRoot) = try await makeTestFileSystem()
        let (_, cloudRoot) = try await makeTestFileSystem()
        let cloud = FileSystemManager(documentsURL: cloudRoot.deletingLastPathComponent(),
                                      localFallbackDocumentsURL: localRoot.deletingLastPathComponent())
        return (local, localRoot, cloud, cloudRoot)
    }

    func testMigrationMergesIntoNonemptyCloudAndPreservesBothConflictingCopies() async throws {
        let (local, _, cloud, _) = try await makeMigrationFileSystems()
        let item = TodoItem(id: "local-only", title: "本地任务")
        let localConflict = TodoItem(id: "shared", title: "本地编辑")
        let cloudConflict = TodoItem(id: "shared", title: "云端编辑")
        try await local.write(item, filename: "task_local-only.json", directory: .tasks)
        try await local.write(localConflict, filename: "task_shared.json", directory: .tasks)
        try await cloud.write(cloudConflict, filename: "task_shared.json", directory: .tasks)
        try await cloud.write(LLMConfig(model: "existing-model"), filename: "llm_config.json", directory: .config)
        let report = try await cloud.setupDirectories()
        XCTAssertEqual(report.copiedFiles, 1)
        XCTAssertEqual(report.conflictFiles, 1)
        let merged = try await TodoRepository(fs: cloud).listAll()
        XCTAssertEqual(Set(merged.map(\.id)), Set([item.id, localConflict.id]))
        XCTAssertEqual(merged.first { $0.id == "shared" }?.title, cloudConflict.title)
        let backups = try await cloud.listFiles(in: .conflicts)
        XCTAssertEqual(backups.count, 1)
        let backup = try await cloud.read(TodoItem.self, filename: XCTUnwrap(backups.first), directory: .conflicts)
        XCTAssertEqual(backup, localConflict)
        let repeated = try await cloud.setupDirectories()
        XCTAssertEqual(repeated.copiedFiles, 0)
        XCTAssertEqual(repeated.conflictFiles, 0)
        let afterRepeat = try await cloud.listFiles(in: .conflicts)
        XCTAssertEqual(afterRepeat, backups)
    }

    func testMigrationReceiptPreventsDeletedTaskFromReappearing() async throws {
        let (local, _, cloud, _) = try await makeMigrationFileSystems()
        let item = TodoItem(id: "task", title: "本地任务")
        try await local.write(item, filename: "task_task.json", directory: .tasks)
        _ = try await cloud.setupDirectories()
        try await cloud.delete(filename: "task_task.json", directory: .tasks)
        let report = try await cloud.setupDirectories()
        XCTAssertEqual(report.copiedFiles, 0)
        let remaining = try await TodoRepository(fs: cloud).listAll()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testInterruptedMigrationResumesAfterCorruptSourceIsRepaired() async throws {
        let (local, localRoot, cloud, _) = try await makeMigrationFileSystems()
        try await local.write(TodoItem(id: "a", title: "第一项"), filename: "task_a.json", directory: .tasks)
        let broken = localRoot.appendingPathComponent("tasks/task_z.json")
        try Data("broken".utf8).write(to: broken)
        do {
            _ = try await cloud.setupDirectories()
            XCTFail("损坏源文件应中止并保留错误")
        } catch {
            XCTAssertEqual(error as? FileSystemError, .invalidFile("task_z.json"))
        }
        let partial = try await TodoRepository(fs: cloud).listAll()
        XCTAssertEqual(partial.map(\.id), ["a"])
        try await local.write(TodoItem(id: "z", title: "修复的第二项"), filename: "task_z.json", directory: .tasks)
        let resumed = try await cloud.setupDirectories()
        XCTAssertEqual(resumed.copiedFiles, 1)
        let all = try await TodoRepository(fs: cloud).listAll()
        XCTAssertEqual(Set(all.map(\.id)), Set(["a", "z"]))
    }

    func testMigrationRetryAfterMissingReceiptDoesNotDuplicateConflictBackup() async throws {
        let (local, _, cloud, _) = try await makeMigrationFileSystems()
        try await local.write(TodoItem(id: "a", title: "本地"), filename: "task_a.json", directory: .tasks)
        try await cloud.write(TodoItem(id: "a", title: "云端"), filename: "task_a.json", directory: .tasks)
        _ = try await cloud.setupDirectories()
        let receipts = try await cloud.listFiles(in: .meta)
        XCTAssertEqual(receipts.count, 1)
        try await cloud.delete(filename: XCTUnwrap(receipts.first), directory: .meta)
        _ = try await cloud.setupDirectories()
        let backups = try await cloud.listFiles(in: .conflicts)
        XCTAssertEqual(backups.count, 1)
    }

    func testMigrationDoesNotOverwriteUndownloadedCloudTask() async throws {
        let (local, _, cloud, cloudRoot) = try await makeMigrationFileSystems()
        try await local.write(TodoItem(id: "a", title: "本地"), filename: "task_a.json", directory: .tasks)
        let placeholder = cloudRoot.appendingPathComponent("tasks/.task_a.json.icloud")
        try Data().write(to: placeholder)
        do {
            _ = try await cloud.setupDirectories()
            XCTFail("云端占位文件不能被当成不存在")
        } catch {
            XCTAssertEqual(error as? FileSystemError, .downloadPending("task_a.json"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: cloudRoot.appendingPathComponent("tasks/task_a.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: placeholder.path))
    }

    func testUndownloadedMigrationReceiptPreventsReimport() async throws {
        let (local, _, cloud, cloudRoot) = try await makeMigrationFileSystems()
        try await local.write(TodoItem(id: "a", title: "本地"), filename: "task_a.json", directory: .tasks)
        _ = try await cloud.setupDirectories()
        let receipts = try await cloud.listFiles(in: .meta)
        let receiptName = try XCTUnwrap(receipts.first)
        try await cloud.delete(filename: receiptName, directory: .meta)
        try await cloud.delete(filename: "task_a.json", directory: .tasks)
        try Data().write(to: cloudRoot.appendingPathComponent("meta/." + receiptName + ".icloud"))
        do {
            _ = try await cloud.setupDirectories()
            XCTFail("回执下载前不得重新导入")
        } catch {
            XCTAssertEqual(error as? FileSystemError, .downloadPending(receiptName))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: cloudRoot.appendingPathComponent("tasks/task_a.json").path))
    }

    @MainActor
    func testFallbackConfigKeyIsStoredBeforeCloudMigration() async throws {
        let (_, localRoot, cloud, cloudRoot) = try await makeMigrationFileSystems()
        let legacy = Data(#"{"apiKey":"fallback-test-key","model":"fallback-model"}"#.utf8)
        let localFile = localRoot.appendingPathComponent("config/llm_config.json")
        try legacy.write(to: localFile)
        let keys = MemoryAPIKeyStorage()
        let store = TodoStore(fs: cloud, keyStorage: keys)
        await store.initialize()
        XCTAssertEqual(store.loadState, .loaded)
        XCTAssertEqual(try keys.load(), "fallback-test-key")
        XCTAssertEqual(store.llmConfig.apiKey, "fallback-test-key")
        XCTAssertEqual(store.llmConfig.model, "fallback-model")
        for url in [localFile, cloudRoot.appendingPathComponent("config/llm_config.json")] {
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
            XCTAssertNil(json?["apiKey"])
        }
    }

    @MainActor
    func testFallbackMigrationKeyFailureDoesNotCopyOrErasePlaintext() async throws {
        let (_, localRoot, cloud, cloudRoot) = try await makeMigrationFileSystems()
        let legacy = Data(#"{"apiKey":"fallback-test-key"}"#.utf8)
        let file = localRoot.appendingPathComponent("config/llm_config.json")
        try legacy.write(to: file)
        let store = TodoStore(fs: cloud, keyStorage: UnavailableAPIKeyStorage())
        await store.initialize()
        guard case .failed = store.loadState else { return XCTFail("密钥迁移失败必须可见") }
        XCTAssertEqual(try Data(contentsOf: file), legacy)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cloudRoot.appendingPathComponent("config/llm_config.json").path))
    }

    @MainActor
    func testSameVersionExternalTodoPreservesLocalCopyAndConvergesWithDisk() async throws {
        let (fs, _) = try await makeTestFileSystem()
        let store = TodoStore(fs: fs, keyStorage: MemoryAPIKeyStorage())
        let local = TodoItem(id: "shared", title: "本机分支", version: 3)
        var remote = local
        remote.title = "远端分支"
        store.todos = [local]
        try await fs.write(remote, filename: "task_shared.json", directory: .tasks)
        await store.applyExternalTodo(remote)
        XCTAssertEqual(store.todos, [remote])
        XCTAssertTrue(store.operationError?.contains("冲突") == true)
        let files = try await fs.listFiles(in: .conflicts)
        XCTAssertEqual(files.count, 1)
        let backup = try await fs.read(TodoItem.self, filename: XCTUnwrap(files.first), directory: .conflicts)
        XCTAssertEqual(backup, local)
        await store.applyExternalTodo(remote)
        let repeated = try await fs.listFiles(in: .conflicts)
        XCTAssertEqual(repeated.count, 1)
    }

    func testICloudEventsAreLimitedToRecognizedFilesInCurrentAppDirectory() {
        let root = URL(fileURLWithPath: "/tmp/cloud/TodoLite", isDirectory: true)
        XCTAssertTrue(iCloudSyncManager.isApplicationItem(root.appendingPathComponent("tasks/task_1.json"), rootURL: root))
        XCTAssertTrue(iCloudSyncManager.isApplicationItem(root.appendingPathComponent("config/llm_config.json"), rootURL: root))
        for path in ["/tmp/other/TodoLite/tasks/task_1.json", "/tmp/cloud/TodoLite-copy/tasks/task_1.json",
                     "/tmp/cloud/TodoLite/tasks/nested/task_1.json", "/tmp/cloud/TodoLite/tasks/other.json",
                     "/tmp/cloud/TodoLite/conflicts/task_1_conflict_x.json", "/tmp/cloud/TodoLite/meta/migration_x.json"] {
            XCTAssertFalse(iCloudSyncManager.isApplicationItem(URL(fileURLWithPath: path), rootURL: root), path)
        }
    }

    // MARK: - Shared Widget Snapshots

    func testWidgetSnapshotPreservesFocusOrderAndDuplicateTitles() {
        let now = Date()
        let a = TodoItem(id: "a", title: "相同标题")
        let b = TodoItem(id: "b", title: "相同标题")
        let c = TodoItem(id: "c", title: "任务三")
        let d = TodoItem(id: "d", title: "任务四")
        let done = TodoItem(id: "done", title: "已完成", status: .done)
        let archived = TodoItem(id: "archived", title: "已归档", status: .archived)
        let focus = FocusSet(date: WidgetData.dayString(for: now), taskIds: ["b", "b", "a", "missing", "done", "archived", "c", "d"])
        let data = WidgetDataStore.snapshot(todos: [a, b, c, d, done, archived], focusSet: focus, at: now)
        XCTAssertEqual(data.count, 4)
        XCTAssertEqual(data.tasks.map(\.id), ["b", "a", "c"])
        XCTAssertEqual(data.tasks.prefix(2).map(\.title), ["相同标题", "相同标题"])
    }

    func testYesterdayFocusCannotProduceTodaysWidgetTasks() throws {
        let now = Date()
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: now))
        let focus = FocusSet(date: WidgetData.dayString(for: yesterday), taskIds: ["a"])
        let data = WidgetDataStore.snapshot(todos: [TodoItem(id: "a", title: "昨日任务")], focusSet: focus, at: now)
        XCTAssertEqual(data.count, 0)
        XCTAssertTrue(data.tasks.isEmpty)
    }

    func testWidgetSnapshotExpiresAtNextDayAndRoundTripsThroughDefaults() throws {
        let suite = "TodoLite.WidgetTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date()
        let snapshot = WidgetData(focusDate: WidgetData.dayString(for: now), count: 1,
                                  tasks: [WidgetTask(id: "a", title: "任务")], updatedAt: now)
        defaults.set(try JSONEncoder().encode(snapshot), forKey: WidgetSnapshotStore.key)
        XCTAssertEqual(WidgetSnapshotStore.load(from: defaults, at: now), snapshot)
        let nextDay = WidgetSnapshotStore.nextDay(after: now)
        let expired = WidgetSnapshotStore.load(from: defaults, at: nextDay)
        XCTAssertEqual(expired.count, 0)
        XCTAssertTrue(expired.tasks.isEmpty)
    }

    func testLegacyWidgetSnapshotIsSafelyExpired() throws {
        let json = Data(#"{"count":3,"titles":["旧任务"],"updatedAt":0}"#.utf8)
        let legacy = try JSONDecoder().decode(WidgetData.self, from: json)
        let valid = legacy.validSnapshot(at: Date())
        XCTAssertEqual(valid.count, 0)
        XCTAssertTrue(valid.tasks.isEmpty)
    }

    func testWidgetNextDayUsesCalendarAcrossDaylightSavingChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8)))
        let next = WidgetSnapshotStore.nextDay(after: start, calendar: calendar)
        XCTAssertEqual(next.timeIntervalSince(start), 23 * 3600)
        XCTAssertEqual(calendar.component(.day, from: next), 9)
        XCTAssertEqual(calendar.component(.hour, from: next), 0)
    }

    // MARK: - Input Safety and Report Materials

    private func shanghaiCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        return calendar
    }

    func testParserPreservesEmailsURLsAndProgrammingSymbols() {
        let input = "联系 foo@example.com 查看 https://example.com/#part 修复 C# 编译 @工作"
        let draft = TodoParser.parse(input)
        XCTAssertEqual(draft.projectName, "工作")
        XCTAssertTrue(draft.tagNames.isEmpty)
        XCTAssertEqual(draft.title, "联系 foo@example.com 查看 https://example.com/#part 修复 C# 编译")
    }

    func testParserPreservesInvalidDateWhenOtherRulesSucceed() {
        let draft = TodoParser.parse("提交报告 @工作 ^not-a-date #紧急")
        XCTAssertEqual(draft.title, "提交报告 ^not-a-date")
        XCTAssertEqual(draft.projectName, "工作")
        XCTAssertEqual(draft.tagNames, ["紧急"])
        XCTAssertNil(draft.dueAt)
    }

    func testParserConsumesCompleteNextWeekPhraseAndDeduplicatesTags() throws {
        let calendar = try shanghaiCalendar()
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 15)))
        let draft = TodoParser.parse("提交 ^next week 报告 #紧急 #紧急 @工作", from: date, calendar: calendar)
        XCTAssertEqual(draft.title, "提交 报告")
        XCTAssertEqual(draft.tagNames, ["紧急"])
        XCTAssertEqual(draft.dueAt, calendar.date(from: DateComponents(year: 2026, month: 10, day: 29)))
    }

    func testNumericDateIncludesTodayAndFindsNextValidLeapDay() throws {
        let calendar = try shanghaiCalendar()
        let base = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 15)))
        XCTAssertEqual(DateResolver.resolve("10/22", from: base, calendar: calendar), calendar.startOfDay(for: base))
        XCTAssertEqual(DateResolver.resolve("10/21", from: base, calendar: calendar),
                       calendar.date(from: DateComponents(year: 2027, month: 10, day: 21)))
        XCTAssertEqual(DateResolver.resolve("2/29", from: base, calendar: calendar),
                       calendar.date(from: DateComponents(year: 2028, month: 2, day: 29)))
        for invalid in ["2026-02-29", "2/30", "2026-10/22", "2026/10-22", "2026-00-01"] {
            XCTAssertNil(DateResolver.resolve(invalid, from: base, calendar: calendar), invalid)
        }
    }

    func testLLMParsingPromptCarriesLocalDateAndTimeZone() throws {
        let calendar = try shanghaiCalendar()
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 1)))
        let messages = LLMParser.messages(for: "明天提交报告", projects: [], tags: [], now: date, calendar: calendar)
        XCTAssertTrue(messages[0].content.contains("2026-10-22"))
        XCTAssertTrue(messages[0].content.contains("Asia/Shanghai"))
        XCTAssertEqual(messages[1].content, "明天提交报告")
    }

    func testReportWeekStartsOnMondayAndExcludesNextMonday() throws {
        var calendar = try shanghaiCalendar()
        calendar.firstWeekday = 1
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 20)))
        let week = ReportWeek(containing: date, calendar: calendar)
        XCTAssertEqual(week.start, calendar.date(from: DateComponents(year: 2026, month: 5, day: 18)))
        XCTAssertEqual(week.end, calendar.date(from: DateComponents(year: 2026, month: 5, day: 25)))
        XCTAssertTrue(week.contains(week.start))
        XCTAssertTrue(week.contains(week.end.addingTimeInterval(-1)))
        XCTAssertFalse(week.contains(week.end))
    }

    func testCompletedWeekGroupsHaveStableDateIdentitiesAcrossYears() throws {
        let calendar = try shanghaiCalendar()
        let firstDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 5, day: 20)))
        let secondDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 20)))
        let items = [TodoItem(id: "old", title: "旧任务", status: .done, completedAt: firstDate),
                     TodoItem(id: "new", title: "新任务", status: .done, completedAt: secondDate),
                     TodoItem(id: "active", title: "进行中", status: .doing, completedAt: secondDate)]
        let groups = CompletedTodoWeek.groups(todos: items, calendar: calendar)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.map(\.id)).count, 2)
        XCTAssertEqual(groups.first?.todos.map(\.id), ["new"])
        XCTAssertTrue(groups.last?.week.title(now: secondDate, calendar: calendar).contains("2025年") == true)
    }

    func testWeeklyReportPreviewIncludesOnlySelectedWeekCompletedTasks() throws {
        let calendar = try shanghaiCalendar()
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 20)))
        let week = ReportWeek(containing: date, calendar: calendar)
        let items = [TodoItem(title: "本周成果", description: "任务细节", status: .done, projectId: "p", completedAt: date),
                     TodoItem(title: "下周内容", status: .done, completedAt: week.end),
                     TodoItem(title: "未完成请求", status: .doing, completedAt: date)]
        let prompt = WeeklyReportPrompt.build(week: week, todos: items, projects: [Project(id: "p", name: "交付")],
                                             template: "自定义格式", activity: "用户选择的说明", calendar: calendar)
        XCTAssertTrue(prompt.contains("2026-05-18 至 2026-05-24"))
        for text in ["本周成果", "任务细节", "交付", "自定义格式", "用户选择的说明"] { XCTAssertTrue(prompt.contains(text), text) }
        XCTAssertFalse(prompt.contains("下周内容"))
        XCTAssertFalse(prompt.contains("未完成请求"))
        let noActivity = WeeklyReportPrompt.build(week: week, todos: items, projects: [], template: "", calendar: calendar)
        XCTAssertFalse(noActivity.contains("AI 辅助工作记录"))
        XCTAssertTrue(noActivity.contains(LLMConfig.defaultReportTemplate))
    }

    private func writeSession(_ objects: [[String: Any]], at url: URL, modified: Date) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let text = try objects.map { object -> String in
            String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
        }.joined(separator: "\n")
        try Data(text.utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
    }

    func testAIActivityReadsOnlySelectedSourcesAndSelectedWeek() async throws {
        let (_, root) = try await makeTestFileSystem()
        let calendar = try shanghaiCalendar()
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 20)))
        let week = ReportWeek(containing: date, calendar: calendar)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        func claude(_ message: String, at time: Date) -> [String: Any] {
            ["type": "user", "cwd": "/projects/TestProject", "timestamp": formatter.string(from: time), "message": ["content": message]]
        }
        let claudeURL = root.appendingPathComponent(".claude/projects/example/session.jsonl")
        try writeSession([claude("选中周内的成果", at: week.start), claude("之前一周", at: week.start.addingTimeInterval(-1)),
                          claude("下周不应出现", at: week.end), claude("<system-reminder>隐藏提示", at: date),
                          ["type": "user", "message": ["content": "无日期不应出现"]]], at: claudeURL, modified: week.end.addingTimeInterval(1000))
        let codexURL = root.appendingPathComponent(".codex/sessions/2026/01/01/rollout.jsonl")
        try writeSession([["type": "session_meta", "payload": ["cwd": "/projects/CodexProject"]],
                          ["type": "response_item", "timestamp": formatter.string(from: date),
                           "payload": ["type": "message", "role": "user", "content": [["type": "input_text", "text": "Codex 周内记录"]]]]],
                         at: codexURL, modified: week.end.addingTimeInterval(1000))
        XCTAssertEqual(AIActivityReader.summary(week: week, sources: [], homeDirectory: root), "")
        let claudeText = AIActivityReader.summary(week: week, sources: [.claude], homeDirectory: root)
        XCTAssertTrue(claudeText.contains("选中周内的成果"))
        XCTAssertTrue(claudeText.contains("TestProject"))
        for excluded in ["之前一周", "下周不应出现", "隐藏提示", "无日期不应出现", "Codex 周内记录"] {
            XCTAssertFalse(claudeText.contains(excluded), excluded)
        }
        let codexText = await AIActivityReader.summaryAsync(week: week, sources: [.codex], homeDirectory: root)
        XCTAssertTrue(codexText.contains("Codex 周内记录"))
        XCTAssertTrue(codexText.contains("CodexProject"))
        XCTAssertFalse(codexText.contains("选中周内的成果"))
    }

    func testCursorActivityRequiresMessageDateInsideSelectedWeek() async throws {
        let (_, root) = try await makeTestFileSystem()
        let calendar = try shanghaiCalendar()
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 20)))
        let week = ReportWeek(containing: date, calendar: calendar)
        let path = root.appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        let bubbles: [[String: Any]] = [
            ["type": "user", "text": "Cursor 选中周", "timestamp": date.timeIntervalSince1970 * 1000],
            ["type": "user", "text": "Cursor 其他周", "createdAt": week.end.timeIntervalSince1970],
            ["type": "user", "text": "Cursor 无日期"]]
        let payload: [String: Any] = ["tabs": [["title": "测试会话", "bubbles": bubbles]]]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
            .replacingOccurrences(of: "'", with: "''")
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE ItemTable(key TEXT, value TEXT)", nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "INSERT INTO ItemTable VALUES('workbench.panel.aichat.view.aichat.chatdata','" + json + "')", nil, nil, nil), SQLITE_OK)
        let text = AIActivityReader.summary(week: week, sources: [.cursor], homeDirectory: root)
        XCTAssertTrue(text.contains("Cursor 选中周"))
        XCTAssertFalse(text.contains("Cursor 其他周"))
        XCTAssertFalse(text.contains("Cursor 无日期"))
    }

}


private final class MemoryAPIKeyStorage: APIKeyStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    func load() throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func save(_ apiKey: String) throws {
        lock.lock()
        defer { lock.unlock() }
        value = apiKey
    }
}

private struct UnavailableAPIKeyStorage: APIKeyStorage {
    func load() throws -> String? { nil }
    func save(_ apiKey: String) throws { throw APIKeyStorageError(status: -1) }
}
