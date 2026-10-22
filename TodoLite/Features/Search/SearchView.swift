import SwiftUI

struct SearchView: View {
    @State private var store = TodoStore.shared
    @State private var indexer = SearchIndexer.shared
    @State private var query = ""
    @State private var searchResults: [TodoItem] = []
    @State private var isSearching = false
    @State private var searchError: String?

    private struct SearchRequest: Equatable {
        let query: String
        let revision: Int
    }

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
                if isSearching {
                    ProgressView("正在搜索…")
                } else if let searchError {
                    EmptyStateView(icon: "exclamationmark.triangle", title: "搜索暂不可用", subtitle: searchError)
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && searchResults.isEmpty {
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
            .task(id: SearchRequest(query: query, revision: store.searchIndexRevision)) {
                await performSearch(query)
            }
        }
    }

    @MainActor
    private func performSearch(_ text: String) async {
        searchError = nil
        searchResults = []
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isSearching = false
            return
        }
        isSearching = true
        do {
            try await Task.sleep(for: .milliseconds(150))
            let ids = try await indexer.search(query: text)
            guard !Task.isCancelled else { return }
            let todos = Dictionary(store.todos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            searchResults = ids.compactMap { todos[$0] }
            isSearching = false
        } catch {
            guard !Task.isCancelled else { return }
            searchError = error.localizedDescription
            isSearching = false
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
