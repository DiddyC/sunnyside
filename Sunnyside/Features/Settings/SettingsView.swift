import SwiftUI

struct SettingsView: View {
    @AppStorage(Appearance.storageKey) private var appearanceRaw = Appearance.dark.rawValue
    @Environment(\.dismiss) private var dismiss

    private var appearance: Binding<Appearance> {
        Binding(get: { Appearance(rawValue: appearanceRaw) ?? .dark },
                set: { appearanceRaw = $0.rawValue })
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Appearance").eyebrowStyle()
                            Picker("Appearance", selection: appearance) {
                                ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            Text("Dark is the Sunnyside look. Light uses the same layout on warm paper. System follows your phone.")
                                .font(.footnote)
                                .foregroundStyle(Color.textTertiary)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("About").eyebrowStyle()
                            VStack(spacing: 0) {
                                row("Version", value: version)
                                Divider().background(Color.appBorder)
                                link("Privacy policy", url: "https://github.com/DiddyC/sunnyside/blob/main/privacy")
                                Divider().background(Color.appBorder)
                                link("How the answer is worked out", url: "https://github.com/DiddyC/sunnyside/blob/main/docs/algorithm.md")
                            }
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldCorner, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.fieldCorner, style: .continuous)
                                .strokeBorder(Color.appBorder, lineWidth: 1))
                            Text("No accounts, no analytics, no ads. The only thing that leaves your phone is the place name you search for, and that goes to Apple Maps.")
                                .font(.footnote)
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                    .padding(AppTheme.screenGutter)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.tint(.sunText) }
            }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.body).foregroundStyle(Color.textPrimary)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 16).frame(minHeight: 48)
    }

    private func link(_ title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(title).font(.body).foregroundStyle(Color.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 16).frame(minHeight: 48)
            .contentShape(Rectangle())
        }
    }
}
