import SwiftUI

/// Reusable grouped category picker with search -- used by Post Job,
/// Browse Jobs' "See all" sheet, and notification preferences.
/// Supports either single-select (tap to pick one, dismiss) or
/// multi-select (checkmarks, stays open) via `selection`.
struct CategoryPickerView: View {
    let categories: [JobCategory]
    @Binding var singleSelection: String?
    var multiSelection: Binding<Set<String>>? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""

    private var isMultiSelect: Bool { multiSelection != nil }

    private var filteredGroups: [(group: String, items: [JobCategory])] {
        let filtered = searchText.isEmpty
            ? categories
            : categories.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }

        let grouped = Dictionary(grouping: filtered, by: { $0.groupName })
        return grouped.keys.sorted().map { key in
            (group: key, items: grouped[key]!.sorted { $0.displayName < $1.displayName })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredGroups, id: \.group) { section in
                    Section(section.group) {
                        ForEach(section.items) { category in
                            row(category)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search categories")
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ category: JobCategory) -> some View {
        if isMultiSelect {
            Button {
                toggleMulti(category.id)
            } label: {
                HStack {
                    Text(category.displayName).foregroundColor(HandzColor.textPrimary)
                    Spacer()
                    if multiSelection?.wrappedValue.contains(category.id) == true {
                        Image(systemName: "checkmark").foregroundColor(HandzColor.primary)
                    }
                }
            }
        } else {
            Button {
                singleSelection = category.id
                dismiss()
            } label: {
                HStack {
                    Text(category.displayName).foregroundColor(HandzColor.textPrimary)
                    Spacer()
                    if singleSelection == category.id {
                        Image(systemName: "checkmark").foregroundColor(HandzColor.primary)
                    }
                }
            }
        }
    }

    private func toggleMulti(_ id: String) {
        guard let binding = multiSelection else { return }
        if binding.wrappedValue.contains(id) {
            binding.wrappedValue.remove(id)
        } else {
            binding.wrappedValue.insert(id)
        }
    }
}
