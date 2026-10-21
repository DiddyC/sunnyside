import SwiftUI

struct ResultView: View {
    @State private var vm: ResultViewModel
    @State private var landed = false
    @State private var scrub: Double = 0
    @State private var reminderState: ReminderState = .idle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum ReminderState { case idle, setting, set, failed }

    init(journey: Journey) {
        _vm = State(initialValue: ResultViewModel(journey: journey))
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            skyGlow

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    routeHeader
                    verdictBlock
                        .opacity(landed ? 1 : 0)
                        .offset(y: landed || reduceMotion ? 0 : 14)

                    compassCard
                        .opacity(landed ? 1 : 0)
                        .scaleEffect(landed || reduceMotion ? 1 : 0.97)

                    if vm.recommendation.hasAnySun {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sun along the way").eyebrowStyle()
                            RouteStripView(recommendation: vm.recommendation)
                            if let sw = vm.firstSwitch, sw.time > Date() {
                                reminderButton(sw)
                            }
                        }
                        .surfaceCard()
                        .opacity(landed ? 1 : 0)
                    }

                    explanation
                        .opacity(landed ? 1 : 0)
                }
                .padding(.horizontal, AppTheme.screenGutter)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .frame(maxWidth: AppTheme.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: vm.shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share this result")
            }
        }
        .sensoryFeedback(.success, trigger: landed) { _, new in new }
        .onAppear {
            if reduceMotion { landed = true }
            else { withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { landed = true } }
        }
    }

    // MARK: - Pieces

    private var routeHeader: some View {
        Text(vm.routeLine)
            .font(.footnote)
            .foregroundStyle(Color.textSecondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verdictBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(vm.eyebrow)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.textSecondary)
            Text(vm.headline)
                .font(.display(104))
                .foregroundStyle(vm.recommendation.hasAnySun ? Color.sunAmber : Color.textPrimary)
                .shadow(color: vm.recommendation.hasAnySun ? Color.sunGlow.opacity(0.35) : .clear, radius: 18)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            Text(vm.subtitle)
                .font(.body)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(vm.accessibilitySummary)
    }

    /// Vehicle seat map inside the sun compass, with a time scrubber.
    private var compassCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(vm.recommendation.hasAnySun ? "Where the sun will be" : "Seat map").eyebrowStyle()
                Spacer()
                if vm.recommendation.hasAnySun {
                    Text(compassTime)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.textPrimary)
                }
            }
            SunCompassView(recommendation: vm.recommendation, progress: $scrub)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)

            if vm.recommendation.hasAnySun {
                Text(compassCaption)
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentTransition(.numericText())
                Slider(value: $scrub, in: 0...1) {
                    Text("Time in trip")
                } minimumValueLabel: {
                    Text("Dep").font(.caption2.weight(.semibold)).foregroundStyle(Color.textTertiary)
                } maximumValueLabel: {
                    Text("Arr").font(.caption2.weight(.semibold)).foregroundStyle(Color.textTertiary)
                }
                .tint(.sunAmber)
                .accessibilityValue(compassTime)
                Text("Drag to see where the sun is at any point of the trip.")
                    .font(.caption2)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .surfaceCard(padding: 14)
    }

    private var compassTime: String {
        SunCompassView(recommendation: vm.recommendation, progress: .constant(scrub)).timeString(at: scrub)
    }

    private var compassCaption: String {
        SunCompassView(recommendation: vm.recommendation, progress: .constant(scrub)).caption
    }

    private func reminderButton(_ sw: (time: Date, newShadySide: SeatSide)) -> some View {
        Button {
            guard reminderState == .idle || reminderState == .failed else { return }
            reminderState = .setting
            Task {
                let ok = await SwitchReminder.schedule(at: sw.time, journey: vm.journey, newShadySide: sw.newShadySide)
                reminderState = ok ? .set : .failed
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: reminderState == .set ? "bell.badge.fill" : "bell")
                Text(reminderLabel(sw.time))
                Spacer()
                if reminderState == .setting { ProgressView().tint(.sunText) }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(reminderState == .set ? Color.textSecondary : Color.sunText)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Color.appSurfaceElevated.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(reminderState == .set || reminderState == .setting)
        .padding(.top, 4)
    }

    private func reminderLabel(_ t: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        f.timeZone = vm.journey.origin.timeZone ?? .current
        switch reminderState {
        case .idle, .setting: return "Remind me before the switch at \(f.string(from: t))"
        case .set: return "Reminder set for 5 min before \(f.string(from: t))"
        case .failed: return "Couldn't set a reminder. Allow notifications and try again."
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How this is worked out").eyebrowStyle()
            Text("Shady Seat follows your route every few minutes, works out where the sun is in the sky, and scores how hard it would shine through each side window. Low sun counts more than noon sun, which mostly hits the roof.")
                .font(.footnote)
                .foregroundStyle(Color.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var skyGlow: some View {
        RadialGradient(
            colors: [Color.skyTint(sunAltitude: vm.departureSunAltitude).opacity(0.16), .clear],
            center: UnitPoint(x: 0.85, y: 0.05), startRadius: 0, endRadius: 420
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
