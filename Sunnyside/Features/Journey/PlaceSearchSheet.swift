import SwiftUI
import MapKit

/// Full-screen place search (Maps pattern): keyboard never covers results,
/// and empty / offline / error states are first-class.
struct PlaceSearchSheet: View {
    let title: String
    let region: MKCoordinateRegion?
    var showCurrentLocation = false
    var onUseCurrentLocation: (() -> Void)? = nil
    let onPick: (PlaceResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = PlaceSearch()
    @State private var query = ""
    @State private var isResolving = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchField
                        .padding(.horizontal, AppTheme.screenGutter)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    content
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(.sunText)
                }
            }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
        }
        .onAppear {
            search.region = region
            focused = true
        }
        .onChange(of: query) { _, q in
            errorMessage = nil
            search.update(query: q)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textTertiary)
            TextField("Station, airport or address", text: $query)
                .focused($focused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(Color.textPrimary)
                .tint(.sunText)
                .accessibilityLabel("\(title) search")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textTertiary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.fieldCorner, style: .continuous)
            .strokeBorder(Color.sunAmber.opacity(0.6), lineWidth: 1))
    }

    @ViewBuilder
    private var content: some View {
        List {
            if showCurrentLocation, query.isEmpty, let use = onUseCurrentLocation {
                Button {
                    use(); dismiss()
                } label: {
                    row(icon: "location.fill", iconColor: .sunAmber,
                        title: "Current location", subtitle: "Uses your phone's location once")
                }
                .listRowBackground(Color.appSurface)
            }

            if let errorMessage {
                statusRow(icon: "exclamationmark.triangle", text: errorMessage)
            } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
                statusRow(icon: "sparkle.magnifyingglass", text: "Try a station, airport, city or street.")
            } else if search.isSearching && search.suggestions.isEmpty {
                statusRow(icon: "ellipsis", text: "Searching…")
            } else if search.suggestions.isEmpty {
                statusRow(icon: "mappin.slash", text: "No matches. Try a station or city name.")
            }

            ForEach(search.suggestions) { s in
                Button {
                    pick(s)
                } label: {
                    row(icon: "mappin", iconColor: .textTertiary, title: s.title, subtitle: s.subtitle)
                }
                .disabled(isResolving)
                .listRowBackground(Color.appSurface)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .overlay(alignment: .top) {
            if isResolving {
                ProgressView().tint(.sunText).padding(.top, 8)
            }
        }
    }

    private func row(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(Color.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.subheadline).foregroundStyle(Color.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func statusRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.textTertiary).frame(width: 22)
            Text(text).font(.subheadline).foregroundStyle(Color.textSecondary)
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func pick(_ s: PlaceSuggestion) {
        isResolving = true
        Task {
            do {
                let place = try await search.resolve(s)
                onPick(place)
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "No connection. Can't look up places right now."
            }
            isResolving = false
        }
    }
}
