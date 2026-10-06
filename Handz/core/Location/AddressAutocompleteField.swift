import SwiftUI
import MapKit

/// A text field with a live dropdown of address suggestions underneath,
/// per spec section 6/48 (reusable component, not duplicated per screen).
struct AddressAutocompleteField: View {
    let placeholder: String
    @Binding var text: String
    var onResolved: (ResolvedAddress) -> Void

    @StateObject private var searchService = AddressSearchService()
    @State private var showingSuggestions = false
    @State private var isProgrammaticUpdate = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(placeholder, text: $text)
                .padding()
                .background(HandzColor.surface)
                .cornerRadius(HandzRadius.md)
                .onChange(of: text) { newValue in
                    if isProgrammaticUpdate {
                        isProgrammaticUpdate = false
                        return
                    }
                    searchService.search(newValue)
                    showingSuggestions = !newValue.isEmpty
                }

            if showingSuggestions && !searchService.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searchService.suggestions.prefix(5)) { suggestion in
                        Button {
                            hideKeyboard()
                            showingSuggestions = false
                            searchService.suggestions = []
                            isProgrammaticUpdate = true
                            text = suggestion.subtitle.isEmpty ? suggestion.title : "\(suggestion.title), \(suggestion.subtitle)"
                            Task {
                                if let resolved = await searchService.resolve(suggestion) {
                                    onResolved(resolved)
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(HandzTypography.body)
                                    .foregroundColor(HandzColor.textPrimary)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(HandzTypography.caption)
                                        .foregroundColor(HandzColor.textSecondary)
                                }
                            }
                            .padding(.horizontal, HandzSpacing.md)
                            .padding(.vertical, HandzSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(HandzColor.surface)
                .cornerRadius(HandzRadius.md)
                
            } 
        }
    }
}

private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
