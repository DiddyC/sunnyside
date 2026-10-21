import SwiftUI

/// "When are you leaving?" — quick choices plus a wheel for anything else.
struct DeparturePickerSheet: View {
    @Binding var leavesNow: Bool
    @Binding var departureDate: Date
    let timeZone: TimeZone
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Date = Date()
    @State private var draftIsNow = true

    private var calendar: Calendar {
        var c = Calendar.current; c.timeZone = timeZone; return c
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    Text("Quick picks").eyebrowStyle()
                    quickPicks

                    Text("Or choose a time").eyebrowStyle()
                    DatePicker("Departure", selection: $draft, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.timeZone, timeZone)
                        .frame(maxWidth: .infinity)
                        .frame(height: 190)
                        .clipped()
                        .onChange(of: draft) { _, _ in draftIsNow = false }
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                            .strokeBorder(Color.appBorder, lineWidth: 1))

                    if timeZone.identifier != TimeZone.current.identifier {
                        Label("Times are local to where you start (\(timeZone.localizedName(for: .shortStandard, locale: .current) ?? timeZone.identifier)).", systemImage: "globe")
                            .font(.footnote).foregroundStyle(Color.textTertiary)
                    }

                    Spacer(minLength: 0)

                    Button(draftIsNow ? "Leave now" : "Leave \(summary(draft))") {
                        leavesNow = draftIsNow
                        if !draftIsNow { departureDate = draft }
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(AppTheme.screenGutter)
                .padding(.top, 6)
            }
            .navigationTitle("When are you leaving?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.tint(.sunText) } }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            draftIsNow = leavesNow
            draft = leavesNow ? roundedUp(Date().addingTimeInterval(3600)) : departureDate
        }
    }

    private var quickPicks: some View {
        let now = Date()
        let picks: [(String, Date?)] = [
            ("Now", nil),
            ("In 1 h", roundedUp(now.addingTimeInterval(3600))),
            ("Tomorrow 8:00", at(hour: 8, daysAhead: 1)),
            ("Tomorrow 17:00", at(hour: 17, daysAhead: 1)),
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(picks, id: \.0) { title, date in
                let selected = date == nil ? draftIsNow : (!draftIsNow && abs(draft.timeIntervalSince(date!)) < 60)
                Button {
                    if let date { draft = date; draftIsNow = false } else { draftIsNow = true }
                } label: {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? Color.appBackground : Color.textPrimary)
                        .frame(maxWidth: .infinity).frame(minHeight: 46)
                        .background(selected ? Color.sunAmber : Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldCorner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.fieldCorner, style: .continuous)
                            .strokeBorder(selected ? Color.clear : Color.appBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .sensoryFeedback(.selection, trigger: draftIsNow)
    }

    private func roundedUp(_ d: Date) -> Date {
        let m = calendar.component(.minute, from: d)
        let add = (15 - m % 15) % 15
        return calendar.date(bySetting: .second, value: 0, of: d.addingTimeInterval(TimeInterval(add * 60))) ?? d
    }

    private func at(hour: Int, daysAhead: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: daysAhead, to: Date()) ?? Date()
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    private func summary(_ d: Date) -> String {
        let f = DateFormatter(); f.timeZone = timeZone
        let day = calendar.isDateInToday(d) ? "today" : calendar.isDateInTomorrow(d) ? "tomorrow" : { f.dateFormat = "EEE d MMM"; return f.string(from: d) }()
        f.dateFormat = nil; f.timeStyle = .short; f.dateStyle = .none
        return "\(day) at \(f.string(from: d))"
    }
}
