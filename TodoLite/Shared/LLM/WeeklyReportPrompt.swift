import Foundation

enum WeeklyReportPrompt {
    static func build(week: ReportWeek, todos: [TodoItem], projects: [Project], template: String, activity: String = "", calendar: Calendar = .current) -> String {
        let custom = template.trimmingCharacters(in: .whitespacesAndNewlines)
        let names = Dictionary(projects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let range = formatter.string(from: week.start) + " 至 " + formatter.string(from: week.end.addingTimeInterval(-1))
        var lines = ["请根据以下所选周完成的任务生成工作周报。", "日期范围：" + range, "", "要求：",
                     custom.isEmpty ? LLMConfig.defaultReportTemplate : custom,
                     "只依据提供的材料描述工作，不把工作请求或未完成事项写成已完成成果。", "", "完成任务："]
        for todo in todos where todo.status == .done && todo.completedAt.map(week.contains) == true {
            let project = todo.projectId.flatMap { names[$0] }
            lines.append("- " + todo.title + (project.map { "（项目：" + $0 + "）" } ?? ""))
            if !todo.description.isEmpty { lines.append("  备注：" + todo.description) }
        }
        if !activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines += ["", "用户选择的 AI 辅助工作记录（仅作任务补充说明）：", activity]
        }
        return lines.joined(separator: "\n")
    }
}
