import SwiftUI
import StoreKit

/// Lifetime unlock. Shown when a free user is out of searches for the day,
/// or from Settings.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ent = Entitlements.shared
    @State private var busy = false
    var reason: String = "You've used today's free search."

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Shady Seat Lifetime")
                            .font(.display(34))
                            .foregroundStyle(Color.textPrimary)
                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        benefit("infinity", "Unlimited searches, every day")
                        benefit("rectangle.slash", "No ads")
                        benefit("iphone.and.arrow.forward", "Yours on every device, forever")
                        benefit("heart", "Supports an independent app")
                    }
                    .surfaceCard()

                    Spacer(minLength: 0)

                    Button {
                        busy = true
                        Task {
                            if await ent.purchaseLifetime() { dismiss() }
                            busy = false
                        }
                    } label: {
                        if busy { ProgressView().tint(Color.appBackground) }
                        else { Text(ent.lifetimeProduct.map { "Unlock for \($0.displayPrice), once" } ?? "Unlock, once") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(busy)

                    HStack {
                        Button("Restore purchase") { Task { await ent.restore() } }
                        Spacer()
                        Button("Not now") { dismiss() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.sunText)

                    if let err = ent.lastError {
                        Text(err).font(.footnote).foregroundStyle(Color.danger)
                    }
                    Text("One-time purchase. No subscription, no account.")
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(AppTheme.screenGutter)
                .padding(.top, 8)
            }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
        }
        .presentationDetents([.large])
        .task { await ent.refresh() }
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(.body, weight: .semibold)).foregroundStyle(Color.sunAmber).frame(width: 24)
            Text(text).font(.body).foregroundStyle(Color.textPrimary)
        }
    }
}

/// Where an ad goes for free users. Today a house banner that sells the unlock;
/// an ad network's banner view (e.g. AdMob's) would replace `content` and keep
/// the same slot, so layout never changes when the network is added.
struct AdSlotView: View {
    @State private var ent = Entitlements.shared
    @State private var showPaywall = false

    var body: some View {
        if Monetization.enabled, Monetization.adsForFreeUsers, !ent.isLifetime {
            Button { showPaywall = true } label: { content }
                .buttonStyle(.plain)
                .sheet(isPresented: $showPaywall) { PaywallView(reason: "Searches without limits, and no ads.") }
        }
    }

    private var content: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").foregroundStyle(Color.sunAmber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Go lifetime").font(.subheadline.weight(.semibold)).foregroundStyle(Color.textPrimary)
                Text("Unlimited searches and no ads, for the price of a coffee. Once.").font(.caption).foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 14).frame(minHeight: 56)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.fieldCorner, style: .continuous).strokeBorder(Color.appBorder, lineWidth: 1))
        .accessibilityLabel("Go lifetime: unlimited searches and no ads")
    }
}
