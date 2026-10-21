import SwiftUI
import CoreLocation

struct JourneyInputView: View {
    @State private var vm = JourneyInputViewModel()
    @State private var journey: Journey?
    @State private var showOriginSearch = false
    @State private var showDestinationSearch = false
    @State private var showDurationPicker = false
    @State private var showDeparturePicker = false
    @State private var showSettings = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        routeCard
                        departureSection
                        vehicleSection
                        durationRow
                        ctaButton
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, AppTheme.screenGutter)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                    .frame(maxWidth: AppTheme.maxContentWidth)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationDestination(item: $journey) { j in
                ResultView(journey: j)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            vm.requestCurrentLocationIfNeeded()
            // Screenshot/QA hook: `-sheet from|to|leaving|duration|settings` opens a sheet on launch.
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-prefill") {
                // Screenshot state: a filled-in form.
                vm.set(destination: PlaceResult(name: "Haifa", coordinate: .init(latitude: 32.794, longitude: 34.989), timeZone: .current))
                vm.vehicle = .train
                var cal = Calendar.current
                cal.timeZone = .current
                let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                vm.departureDate = cal.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow) ?? tomorrow
                vm.leavesNow = false
            }
            if let i = args.firstIndex(of: "-sheet"), i + 1 < args.count {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                switch args[i + 1] {
                case "from": showOriginSearch = true
                case "to": showDestinationSearch = true
                case "leaving": showDeparturePicker = true
                case "duration": showDurationPicker = true
                case "settings": showSettings = true
                default: break
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showOriginSearch) {
            PlaceSearchSheet(title: "From", region: vm.searchRegion, nearbyCenter: vm.nearbyCenter,
                             showCurrentLocation: vm.locationState != .denied,
                             onUseCurrentLocation: { vm.useCurrentLocation() },
                             onPick: { vm.set(origin: $0) })
        }
        .sheet(isPresented: $showDestinationSearch) {
            PlaceSearchSheet(title: "To", region: vm.searchRegion, nearbyCenter: vm.nearbyCenter, onPick: { vm.set(destination: $0) })
        }
        .sheet(isPresented: $showDurationPicker) {
            DurationPickerSheet(estimate: vm.estimatedDuration ?? 3600, override: $vm.durationOverride)
        }
        .sheet(isPresented: $showDeparturePicker) {
            DeparturePickerSheet(leavesNow: $vm.leavesNow, departureDate: $vm.departureDate, timeZone: vm.originTimeZone)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sunnyside")
                    .font(.display(40))
                    .foregroundStyle(Color.textPrimary)
                Text("Find the shady side before you sit.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Settings")
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(Color.sunAmber)
                .shadow(color: Color.sunGlow.opacity(0.5), radius: 14)
                .accessibilityHidden(true)
        }
        .padding(.top, 8)
    }

    // MARK: - Route

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .trailing) {
                VStack(spacing: 0) {
                    routeRow(label: "From", icon: originIcon, iconColor: vm.effectiveOrigin != nil ? .sunAmber : .textTertiary,
                             text: originText, isPlaceholder: vm.effectiveOrigin == nil && vm.locationState != .locating) {
                        showOriginSearch = true
                    }
                    .accessibilityHint("Choose where you start")

                    Divider().overlay(Color.appBorder).padding(.leading, 50).padding(.trailing, 64)

                    routeRow(label: "To", icon: "mappin.circle.fill", iconColor: vm.destination != nil ? .sunAmber : .textTertiary,
                             text: vm.destination?.name ?? "Where to?", isPlaceholder: vm.destination == nil) {
                        showDestinationSearch = true
                    }
                    .accessibilityHint("Choose your destination")
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1))

                Button {
                    withAnimation(.snappy) { vm.swapEnds() }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Color.appSurfaceElevated)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 1))
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 14)
                .disabled(vm.effectiveOrigin == nil || vm.destination == nil)
                .opacity(vm.effectiveOrigin == nil || vm.destination == nil ? 0.45 : 1)
                .accessibilityLabel("Swap start and destination")
            }

            if vm.locationState == .denied && vm.origin == nil {
                locationDeniedNote
            } else if vm.locationState == .failed && vm.origin == nil {
                inlineNote(icon: "location.slash", text: "Couldn't find your location. Type where you start, or try again from the From field.", color: .textSecondary)
            } else if vm.isTooShort {
                inlineNote(icon: "exclamationmark.circle", text: "Start and destination are the same place.", color: .danger)
            }
        }
    }

    private var originIcon: String {
        vm.originMode == .currentLocation ? "location.fill" : "circle.fill"
    }

    private var originText: String {
        switch (vm.originMode, vm.locationState) {
        case (.currentLocation, .locating): return "Finding you…"
        case (.currentLocation, .located): return "Current location"
        case (.place, _): return vm.origin?.name ?? "Where from?"
        default: return "Where from?"
        }
    }

    private func routeRow(label: String, icon: String, iconColor: Color, text: String,
                          isPlaceholder: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).eyebrowStyle()
                    Text(text)
                        .font(.body.weight(.medium))
                        .foregroundStyle(isPlaceholder ? Color.textTertiary : Color.textPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.trailing, 44)   // room for the swap button
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label): \(text)")
    }

    private var locationDeniedNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            inlineNote(icon: "location.slash", text: "Location is off. Type where you start, or turn it on in Settings.", color: .textSecondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.sunText)
            .padding(.leading, 34)
        }
        .padding(.top, 10)
    }

    private func inlineNote(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).font(.caption.weight(.semibold)).foregroundStyle(color)
            Text(text).font(.footnote).foregroundStyle(color)
        }
        .padding(.top, 10)
        .padding(.leading, 4)
    }

    // MARK: - Departure

    private var departureSection: some View {
        Button {
            showDeparturePicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: vm.leavesNow ? "clock.fill" : "calendar")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Color.sunAmber)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Leaving").eyebrowStyle()
                    Text(vm.departureText)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .strokeBorder(Color.appBorder, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Leaving \(vm.departureText)")
        .accessibilityHint("Choose a departure time")
    }

    // MARK: - Vehicle

    private var vehicleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Travelling by").eyebrowStyle()
            VehiclePicker(selected: $vm.vehicle) { vm.select(vehicle: $0) }
        }
    }

    // MARK: - Duration

    @ViewBuilder
    private var durationRow: some View {
        if let d = vm.duration {
            Button {
                showDurationPicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .foregroundStyle(Color.textTertiary)
                    Text(vm.durationOverride == nil ? "About \(Journey.format(duration: d))" : "Trip time \(Journey.format(duration: d))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(vm.durationOverride == nil ? "Edit" : "Edited")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.sunText)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .background(Color.appSurface.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldCorner, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Trip time, \(Journey.format(duration: d)). Edit.")
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            journey = vm.buildJourney()
        } label: {
            Label("Find my seat", systemImage: "sun.and.horizon.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!vm.canSearch)
        .animation(.easeInOut(duration: 0.2), value: vm.canSearch)
    }
}

extension Journey: Hashable, Identifiable {
    var id: String { "\(origin.coordinate.latitude),\(origin.coordinate.longitude)>\(destination.coordinate.latitude),\(destination.coordinate.longitude)@\(departureTime.timeIntervalSince1970)/\(vehicle.rawValue)/\(durationOverride ?? -1)" }
    func hash(into h: inout Hasher) { h.combine(id) }
}
