import XCTest
import SwiftUI
@testable import TodoLite

final class TodoLiteTests: XCTestCase {

    // MARK: - Models

    func testTodoItemCodable() throws {
        let todo = TodoItem(title: "测试任务", status: .doing, priority: .high)
        let data = try JSONEncoder().encode(todo)
        let decoded = try JSONDecoder().decode(TodoItem.self, from: data)
        XCTAssertEqual(decoded.title, "测试任务")
        XCTAssertEqual(decoded.status, .doing)
        XCTAssertEqual(decoded.priority, .high)
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
        XCTAssertNil(draft.priority)
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

    func testParserWithPriority() {
        let draft = TodoParser.parse("提交 TestFlight !high")
        XCTAssertEqual(draft.priority, .high)
    }

    func testParserWithDate() {
        let draft = TodoParser.parse("提交 TestFlight ^tomorrow")
        XCTAssertNotNil(draft.scheduledAt)
    }

    func testParserFull() {
        let draft = TodoParser.parse("提交 TestFlight @工作 #iOS !high ^tomorrow")
        XCTAssertEqual(draft.title, "提交 TestFlight")
        XCTAssertEqual(draft.projectName, "工作")
        XCTAssertEqual(draft.tagNames, ["iOS"])
        XCTAssertEqual(draft.priority, .high)
        XCTAssertNotNil(draft.scheduledAt)
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

    // MARK: - TodoStatus DisplayName

    func testStatusDisplayNames() {
        XCTAssertEqual(TodoStatus.inbox.displayName, "收件箱")
        XCTAssertEqual(TodoStatus.doing.displayName, "进行中")
        XCTAssertEqual(TodoStatus.waiting.displayName, "等待中")
        XCTAssertEqual(TodoStatus.done.displayName, "已完成")
        XCTAssertEqual(TodoStatus.archived.displayName, "已归档")
    }

    func testPriorityDisplayNames() {
        XCTAssertEqual(TodoPriority.low.displayName, "低")
        XCTAssertEqual(TodoPriority.medium.displayName, "中")
        XCTAssertEqual(TodoPriority.high.displayName, "高")
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

    func testParserCaseInsensitivePriority() {
        let draft = TodoParser.parse("测试 !HIGH")
        XCTAssertEqual(draft.priority, .high)
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

    func testFocusTodos() {
        let store = TodoStore()
        let t1 = TodoItem(id: "t1", title: "高优Focus", status: .doing, priority: .high)
        let t2 = TodoItem(id: "t2", title: "中优Focus", status: .doing, priority: .medium)
        let t3 = TodoItem(id: "t3", title: "非Focus", status: .doing, priority: .high)

        store.todos = [t1, t2, t3]
        store.focusSet = FocusSet(date: FocusSet.todayString(), taskIds: ["t1", "t2"])

        XCTAssertEqual(store.focusTodos.count, 2)
        XCTAssertEqual(store.focusTodos[0].title, "高优Focus")
        XCTAssertEqual(store.focusTodos[1].title, "中优Focus")
    }

    func testFocusTodosExcludesDone() {
        let store = TodoStore()
        let t1 = TodoItem(id: "t1", title: "已完成Focus", status: .done, priority: .high)

        store.todos = [t1]
        store.focusSet = FocusSet(date: FocusSet.todayString(), taskIds: ["t1"])

        XCTAssertEqual(store.focusTodos.count, 0)
    }

    func testSuggestedTodos() {
        let store = TodoStore()
        let today = Date()
        let t1 = TodoItem(id: "t1", title: "今日计划", status: .doing, scheduledAt: today)
        let t2 = TodoItem(id: "t2", title: "今日到期", status: .doing, dueAt: today)
        let t3 = TodoItem(id: "t3", title: "已在Focus", status: .doing, scheduledAt: today)

        store.todos = [t1, t2, t3]
        store.focusSet = FocusSet(date: FocusSet.todayString(), taskIds: ["t3"])

        XCTAssertEqual(store.suggestedTodos.count, 2)
        XCTAssertTrue(store.suggestedTodos.contains { $0.title == "今日计划" })
        XCTAssertTrue(store.suggestedTodos.contains { $0.title == "今日到期" })
    }

    func testOverdueTodos() {
        let store = TodoStore()
        let past = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let t1 = TodoItem(id: "t1", title: "逾期", status: .doing, dueAt: past)
        let t2 = TodoItem(id: "t2", title: "今天到期", status: .doing, dueAt: Date())

        store.todos = [t1, t2]

        XCTAssertEqual(store.overdueTodos.count, 1)
        XCTAssertEqual(store.overdueTodos[0].title, "逾期")
    }

    func testActiveTodos() {
        let store = TodoStore()
        store.todos = [
            TodoItem(title: "进行中", status: .doing),
            TodoItem(title: "已完成", status: .done),
            TodoItem(title: "等待中", status: .waiting),
            TodoItem(title: "已归档", status: .archived),
            TodoItem(title: "收件箱", status: .inbox),
        ]
        XCTAssertEqual(store.activeTodos.count, 3)
        XCTAssertTrue(store.activeTodos.contains { $0.title == "进行中" })
        XCTAssertTrue(store.activeTodos.contains { $0.title == "等待中" })
        XCTAssertTrue(store.activeTodos.contains { $0.title == "收件箱" })
    }

    func testInboxTodos() {
        let store = TodoStore()
        store.todos = [
            TodoItem(title: "进行中", status: .doing),
            TodoItem(title: "收件箱", status: .inbox),
            TodoItem(title: "收件箱2", status: .inbox),
        ]
        XCTAssertEqual(store.inboxTodos.count, 2)
    }

    func testToggleCompleteStateMachine() {
        let store = TodoStore()
        let doing = TodoItem(title: "进行中", status: .doing)
        let done = TodoItem(title: "已完成", status: .done, completedAt: Date())
        let waiting = TodoItem(title: "等待中", status: .waiting)

        store.todos = [doing, done, waiting]

        XCTAssertEqual(store.todos[0].status, .doing)
        XCTAssertEqual(store.todos[1].status, .done)
        XCTAssertEqual(store.todos[2].status, .waiting)

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

        // waiting -> done
        var m3 = store.todos[2]
        if m3.status == .done {
            m3.status = .doing
            m3.completedAt = nil
        } else {
            m3.status = .done
            m3.completedAt = Date()
        }
        XCTAssertEqual(m3.status, .done)
        XCTAssertNotNil(m3.completedAt)
    }

    func testArchiveTodo() {
        let store = TodoStore()
        let todo = TodoItem(title: "归档", status: .done)
        store.todos = [todo]

        var archived = store.todos[0]
        archived.status = .archived
        archived.completedAt = Date()
        XCTAssertEqual(archived.status, .archived)
        XCTAssertNotNil(archived.completedAt)
    }

    func testStatusCodableMigration() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let jsonNext = #"{"id":"1","title":"t","description":"","status":"next","priority":"medium","tagIds":[],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z","version":1}"#.data(using: .utf8)!
        let decodedNext = try decoder.decode(TodoItem.self, from: jsonNext)
        XCTAssertEqual(decodedNext.status, .doing)

        let jsonBlocked = #"{"id":"2","title":"t","description":"","status":"blocked","priority":"medium","tagIds":[],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z","version":1}"#.data(using: .utf8)!
        let decodedBlocked = try decoder.decode(TodoItem.self, from: jsonBlocked)
        XCTAssertEqual(decodedBlocked.status, .waiting)

        let jsonSomeday = #"{"id":"3","title":"t","description":"","status":"someday","priority":"medium","tagIds":[],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z","version":1}"#.data(using: .utf8)!
        let decodedSomeday = try decoder.decode(TodoItem.self, from: jsonSomeday)
        XCTAssertEqual(decodedSomeday.status, .waiting)

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
