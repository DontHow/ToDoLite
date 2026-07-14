import SwiftUI

struct SearchView: View {
    @State private var store = TodoStore.shared
    @State private var indexer = SearchIndexer.shared
    @State private var query = ""
    @State private var searchResults: [TodoItem] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(searchResults) { todo in
                        TodoListCard(todo: todo)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
            }
            .navigationTitle("搜索")
            .searchable(text: $query)
            .overlay {
                if query.isEmpty && searchResults.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "搜索任务",
                        subtitle: "输入关键词搜索标题、描述、标签和项目"
                    )
                } else if searchResults.isEmpty && !query.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass.circle",
                        title: "无结果",
                        subtitle: "换个关键词试试"
                    )
                }
            }
            .onChange(of: query) { _, newValue in
                performSearch(newValue)
            }
            .onChange(of: store.todos) { _, _ in
                performSearch(query)
            }
            .onChange(of: store.projects) { _, _ in
                performSearch(query)
            }
            .onChange(of: store.tags) { _, _ in
                performSearch(query)
            }
        }
    }

    private func performSearch(_ text: String) {
        guard !text.isEmpty else {
            searchResults = []
            return
        }
        Task {
            let ids = await indexer.search(query: text)
            let matched = ids.compactMap { id in store.todos.first { $0.id == id } }
            await MainActor.run {
                guard query == text else { return }
                searchResults = matched
            }
        }
    }

    private var horizontalPadding: CGFloat {
        #if os(iOS)
        16
        #else
        12
        #endif
    }
}
