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
                coreInfoPanel(expandsDescription: true)
                    .frame(minWidth: 280, maxWidth: 320, alignment: .top)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.trailing, 16)
                    .layoutPriority(2)

                Divider()

                dueDatePanel(compactCalendar: true)
                    .frame(minWidth: 300, maxWidth: 340, alignment: .top)
                    .padding(.horizontal, 16)
                    .layoutPriority(2)

                Divider()

                projectSelector
                    .frame(minWidth: 210, maxWidth: 240, alignment: .top)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .layoutPriority(1)

                Divider()

                ScrollView {
                    VStack(spacing: 16) {
                        statusSelector
                        tagSelector(scrollsList: false)
                    }
                }
                .scrollIndicators(.visible)
                .frame(minWidth: 190, maxWidth: 220, alignment: .top)
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
            coreInputPanel
            attributesPanel
        }
    }

    var coreInputPanel: some View {
        VStack(spacing: 18) {
            coreInfoPanel()
            dueDatePanel()
        }
    }

    func coreInfoPanel(expandsDescription: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: "square.and.pencil", color: .accentColor, title: "核心信息")

            TextField("任务标题", text: $edited.title)
                .appFont(.title3, weight: .semibold)
                .focused($detailTitleFocused)

            ruleSuggestions

            Divider()

            ZStack(alignment: .topLeading) {
                if edited.description.isEmpty {
                    Text("添加描述...")
                        .appFont(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $edited.description)
                    .appFont(.body)
                    .foregroundStyle(Color.labelSecondary)
                    .scrollContentBackground(.hidden)
            }
            .frame(
                minHeight: 140,
                maxHeight: expandsDescription ? .infinity : 140
            )

            Divider()

            parsingControls
                .task(id: edited.title) {
                    await automaticallyApplyRuleParsing(to: edited.title)
                }
        }
        .frame(maxHeight: expandsDescription ? .infinity : nil, alignment: .top)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.cardBackground)
        )
    }

    func dueDatePanel(compactCalendar: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "calendar", color: .orange, title: "截止日期")

            HStack(spacing: 8) {
                quickDateButton("今天", date: Date())
                quickDateButton("明天", date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                quickDateButton("下周一", date: nextMonday())
                customDateButton
            }

            CalendarPicker(
                selectedDate: $edited.dueAt,
                isCompact: compactCalendar
            )

            if let completedAt = edited.completedAt {
                Divider()
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .appFont(.body)
                        .symbolRenderingMode(.hierarchical)
                    Text("完成于 \(completedAt.formatted(.dateTime.year().month().day().hour().minute()))")
                        .appFont(.body)
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
