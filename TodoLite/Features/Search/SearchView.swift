import SwiftUI

struct SearchView: View {
    @State private var store = TodoStore.shared
    @State private var indexer = SearchIndexer.shared
    @State private var query = ""
    @State private var searchResults: [TodoItem] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(searchResults) { todo in
                    NavigationLink(value: todo) {
                        TodoRowView(todo: todo)
                    }
                }
            }
            .navigationTitle("搜索")
            .searchable(text: $query)
            .onChange(of: query) { _, newValue in
                performSearch(newValue)
            }
            .navigationDestination(for: TodoItem.self) { todo in
                TodoDetailView(todo: todo)
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
                searchResults = matched
            }
        }
    }
}
