import Foundation
import StoreKit
import Observation

/// StoreKit 2 wrapper: the lifetime unlock plus the free daily quota.
@MainActor
@Observable
final class Entitlements {
    static let shared = Entitlements()

    private(set) var isLifetime = false
    private(set) var lifetimeProduct: Product?
    private(set) var isLoading = false
    private(set) var lastError: String?

    private var updates: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private let dateKey = "freeSearchDate", countKey = "freeSearchCount"

    private init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result {
                    await self?.apply(t)
                    await t.finish()
                }
            }
        }
    }

    // MARK: Entitlement

    /// Call once at launch and whenever the paywall appears.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result { apply(t) }
        }
        if lifetimeProduct == nil {
            lifetimeProduct = try? await Product.products(for: [Monetization.lifetimeProductID]).first
        }
    }

    private func apply(_ t: Transaction) {
        guard t.productID == Monetization.lifetimeProductID else { return }
        isLifetime = t.revocationDate == nil
    }

    /// Returns true when the purchase completed (or was already owned).
    func purchaseLifetime() async -> Bool {
        lastError = nil
        if lifetimeProduct == nil {
            lifetimeProduct = try? await Product.products(for: [Monetization.lifetimeProductID]).first
        }
        guard let product = lifetimeProduct else {
            lastError = "The App Store didn't return the product. Try again in a moment."
            return false
        }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let t) = verification else { lastError = "Purchase could not be verified."; return false }
                apply(t); await t.finish(); return true
            case .userCancelled: return false
            case .pending: lastError = "Purchase is pending approval."; return false
            @unknown default: return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        lastError = nil
        try? await AppStore.sync()
        await refresh()
        if !isLifetime { lastError = "No lifetime purchase found for this Apple ID." }
    }

    // MARK: Free quota

    /// True when the user may run a search right now.
    var canSearchToday: Bool {
        !Monetization.enabled || isLifetime || searchesUsedToday < Monetization.freeSearchesPerDay
    }

    var searchesLeftToday: Int {
        max(0, Monetization.freeSearchesPerDay - searchesUsedToday)
    }

    private var todayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    private var searchesUsedToday: Int {
        defaults.string(forKey: dateKey) == todayKey ? defaults.integer(forKey: countKey) : 0
    }

    /// Record a search against today's quota (no-op for lifetime users or when rails are off).
    func recordSearch() {
        guard Monetization.enabled, !isLifetime else { return }
        let used = searchesUsedToday
        defaults.set(todayKey, forKey: dateKey)
        defaults.set(used + 1, forKey: countKey)
    }
}
