import SwiftUI

/// Lets the traveller enter the trip length from their ticket.
struct DurationPickerSheet: View {
    let estimate: TimeInterval
    @Binding var override: TimeInterval?
    @Environment(\.dismiss) private var dismiss
    @State private var hours = 0
    @State private var minutes = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("How long is the trip?")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text("Use the time on your ticket. The estimate is \(Journey.format(duration: estimate)).")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 0) {
                        Picker("Hours", selection: $hours) {
                            ForEach(0..<25, id: \.self) { Text("\($0) h").tag($0) }
                        }
                        Picker("Minutes", selection: $minutes) {
                            ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) min").tag($0) }
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 180)
                    .foregroundStyle(Color.textPrimary)

                    Button("Use this time") {
                        let total = TimeInterval(hours * 3600 + minutes * 60)
                        override = total > 0 ? total : nil
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if override != nil {
                        Button("Back to the estimate") { override = nil; dismiss() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.sunText)
                    }
                    Spacer()
                }
                .padding(AppTheme.screenGutter)
                .padding(.top, 12)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.tint(.sunText) }
            }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            let base = override ?? estimate
            let m = Int((base / 60).rounded())
            hours = min(24, m / 60)
            minutes = (m % 60) / 5 * 5
        }
    }
}
