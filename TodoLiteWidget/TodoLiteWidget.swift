import WidgetKit
import SwiftUI

struct WidgetData: Codable {
    let count: Int
    let titles: [String]
    let updatedAt: Date
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), count: 3, titles: ["任务一", "任务二"])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }

    private func loadEntry() -> SimpleEntry {
        let suiteName = "group.com.donghao.TodoLite"
        let key = "widgetData"
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return SimpleEntry(date: Date(), count: 0, titles: [])
        }
        return SimpleEntry(date: decoded.updatedAt, count: decoded.count, titles: decoded.titles)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let count: Int
    let titles: [String]
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

            if entry.titles.isEmpty {
                Text("没有任务")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.titles, id: \.self) { title in
                    HStack(spacing: 4) {
                        Image(systemName: "circle")
                            .font(.caption2)
                        Text(title)
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
