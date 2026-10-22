import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), count: 3, tasks: [WidgetTask(id: "1", title: "任务一"), WidgetTask(id: "2", title: "任务二")])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let now = Date()
        let entry = loadEntry(at: now)
        let nextDay = WidgetSnapshotStore.nextDay(after: now)
        // 即使系统尚未重新请求 timeline，也会在跨日时切换为空的今日快照。
        let reset = SimpleEntry(date: nextDay, count: 0, tasks: [])
        completion(Timeline(entries: [entry, reset], policy: .after(nextDay)))
    }

    private func loadEntry(at date: Date = Date()) -> SimpleEntry {
        let snapshot = WidgetSnapshotStore.load(from: UserDefaults(suiteName: WidgetSnapshotStore.suiteName), at: date)
        return SimpleEntry(date: date, count: snapshot.count, tasks: snapshot.tasks)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let count: Int
    let tasks: [WidgetTask]
}

struct TodoLiteWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                Text("今日")
                    .font(.headline)
                Spacer()
                Text("\(entry.count)")
                    .font(.title2.bold())
                    .foregroundStyle(.blue)
            }

            if entry.tasks.isEmpty {
                Text("没有任务")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.tasks) { task in
                    HStack(spacing: 4) {
                        Image(systemName: "circle")
                            .font(.caption2)
                        Text(task.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding()
    }
}

struct TodoLiteWidget: Widget {
    let kind: String = "TodoLiteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TodoLiteWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("办他")
        .description("查看今天的待办任务")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
