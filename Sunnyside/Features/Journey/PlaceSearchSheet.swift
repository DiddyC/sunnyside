import SwiftUI
import MapKit
import CoreLocation

/// Full-screen place search (Maps pattern). Empty query shows what a traveller
/// most likely wants: current location, recent places, and the stations and
/// airports around them. Typing searches Apple Maps.
struct PlaceSearchSheet: View {
    let title: String
    let region: MKCoordinateRegion?
    var nearbyCenter: CLLocationCoordinate2D? = nil
    var showCurrentLocation = false
    var onUseCurrentLocation: (() -> Void)? = nil
    let onPick: (PlaceResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = PlaceSearch()
    @State private var query = ""
    @State private var isResolving = false
    @State private var errorMessage: String?
    @State private var recents: [PlaceResult] = []
    @State private var nearby: [NearbyPlace] = []
    @State private var nearbyLoaded = false
    @FocusState private var focused: Bool

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchField
                        .padding(.horizontal, AppTheme.screenGutter)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            if trimmed.isEmpty { idleContent } else { resultsContent }
                        }
                        .padding(.horizontal, AppTheme.screenGutter)
                        .padding(.bottom, 32)
                    }
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.tint(.sunText) }
            }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
        }
        .onAppear {
            search.region = region
            recents = RecentPlaces.load()
            focused = true
        }
        .task {
            guard let c = nearbyCenter else { nearbyLoaded = true; return }
            nearby = await PlaceSearch.nearbyTransit(around: c)
            nearbyLoaded = true
        }
        .onChange(of: query) { _, q in
            errorMessage = nil
            search.update(query: q)
        }
    }

    // MARK: Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.sunText)
            TextField("City, station, airport or address", text: $query)
                .focused($focused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(Color.textPrimary)
                .tint(.sunText)
                .accessibilityLabel("\(title) search")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.textTertiary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.fieldCorner, style: .continuous)
            .strokeBorder(Color.sunAmber.opacity(0.7), lineWidth: 1.2))
    }

    // MARK: Idle (no query)

    @ViewBuilder
    private var idleContent: some View {
        if showCurrentLocation, let use = onUseCurrentLocation {
            group {
                row(icon: "location.fill", iconColor: .sunAmber, title: "Current location", subtitle: "Uses your phone's position once") {
                    use(); dismiss()
                }
            }
        }

        if !recents.isEmpty {
            section("Recent") {
                group {
                    ForEach(Array(recents.enumerated()), id: \.offset) { i, p in
                        row(icon: "clock.arrow.circlepath", iconColor: .textTertiary, title: p.name, subtitle: "") {
                            onPick(p); dismiss()
                        }
                        if i < recents.count - 1 { divider }
                    }
                }
            }
        }

        if nearbyCenter != nil {
            section("Stations and airports near you") {
                if !nearbyLoaded {
                    statusRow(icon: "ellipsis", text: "Looking around you…")
                } else if nearby.isEmpty {
                    statusRow(icon: "tram", text: "No stations or airports within 40 km. Try searching.")
                } else {
                    group {
                        ForEach(Array(nearby.enumerated()), id: \.element.id) { i, n in
                            row(icon: n.icon, iconColor: .shadeBlue, title: n.place.name, subtitle: n.distanceText) {
                                onPick(n.place); dismiss()
                            }
                            if i < nearby.count - 1 { divider }
                        }
                    }
                }
            }
        } else if recents.isEmpty {
            statusRow(icon: "sparkle.magnifyingglass", text: "Type a city, a station, an airport or a street.")
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultsContent: some View {
        if let errorMessage {
            statusRow(icon: "exclamationmark.triangle", text: errorMessage)
        } else if search.isSearching && search.suggestions.isEmpty {
            statusRow(icon: "ellipsis", text: "Searching…")
        } else if search.suggestions.isEmpty {
            statusRow(icon: "mappin.slash", text: "No matches. Try a city or station name.")
        } else {
            section("Results") {
                group {
                    ForEach(Array(search.suggestions.enumerated()), id: \.element.id) { i, s in
                        row(icon: "mappin", iconColor: .textTertiary, title: s.title, subtitle: s.subtitle) { pick(s) }
                            .disabled(isResolving)
                        if i < search.suggestions.count - 1 { divider }
                    }
                }
            }
            if isResolving {
                HStack(spacing: 8) { ProgressView().tint(.sunText); Text("Pinning it on the map…").font(.footnote).foregroundStyle(Color.textSecondary) }
            }
        }
    }

    // MARK: Pieces

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).eyebrowStyle()
            content()
        }
    }

    private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .strokeBorder(Color.appBorder, lineWidth: 1))
    }

    private var divider: some View {
        Divider().overlay(Color.appBorder).padding(.leading, 50)
    }

    private func row(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.medium)).foregroundStyle(Color.textPrimary).lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.subheadline).foregroundStyle(Color.textSecondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.textTertiary).frame(width: 22)
            Text(text).font(.subheadline).foregroundStyle(Color.textSecondary)
        }
        .padding(.vertical, 6)
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
