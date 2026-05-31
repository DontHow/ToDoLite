import SwiftUI

extension CreateTodoView {
    var detailForm: some View {
        ViewThatFits(in: .horizontal) {
            if usesWideDetailLayout {
                wideDetailForm
            }

            compactDetailForm
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                detailTitleFocused = true
            }
        }
    }

    var usesWideDetailLayout: Bool {
        horizontalSizeClass != .compact
    }

    var wideDetailForm: some View {
        HStack(alignment: .top, spacing: 0) {
            if todo == nil {
                VStack(spacing: 18) {
                    inlineModeToggle
                    coreInputPanel
                }
                .frame(minWidth: 320, maxWidth: 380, alignment: .top)
                .padding(.trailing, 16)
                .layoutPriority(2)

                Divider()

                VStack(spacing: 16) {
                    projectSelector
                }
                .frame(minWidth: 220, maxWidth: 260, alignment: .top)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .layoutPriority(1)

                Divider()

                VStack(spacing: 16) {
                    statusSelector
                    tagSelector
                }
                .frame(minWidth: 200, maxWidth: 240, alignment: .top)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .layoutPriority(1)
            } else {
                coreInputPanel
                    .frame(minWidth: 360, maxWidth: .infinity, alignment: .top)
                    .padding(.trailing, 20)

                Divider()
                    .padding(.horizontal, 0)

                attributesPanel
                    .frame(width: 340, alignment: .top)
                    .padding(.leading, 20)
            }
        }
    }

    var compactDetailForm: some View {
        VStack(spacing: 18) {
            if todo == nil {
                inlineModeToggle
            }

            coreInputPanel
            attributesPanel
        }
    }

    var coreInputPanel: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(icon: "square.and.pencil", color: .accentColor, title: "核心信息")

                TextField("任务标题", text: $edited.title)
                    .font(.title3.weight(.semibold))
                    .focused($detailTitleFocused)

                Divider()

                TextField("添加描述...", text: $edited.description, axis: .vertical)
                    .lineLimit(5...9)
                    .font(.body)
                    .foregroundStyle(Color.labelSecondary)
                    .frame(minHeight: 100, alignment: .topLeading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.cardBackground)
            )

            dueDatePanel
        }
    }

    var dueDatePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "calendar", color: .orange, title: "截止日期")

            HStack(spacing: 8) {
                quickDateButton("今天", date: Date())
                quickDateButton("明天", date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                quickDateButton("下周一", date: nextMonday())
                customDateButton
            }

            CalendarPicker(selectedDate: $edited.dueAt)

            if let completedAt = edited.completedAt {
                Divider()
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                    Text("完成于 \(completedAt.formatted(.dateTime.year().month().day().hour().minute()))")
                        .font(.body)
                        .foregroundStyle(Color.labelSecondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.cardBackground)
        )
    }
}
