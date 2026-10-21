import Foundation

/// Monetization rails. Everything here is wired but switched OFF for 2.0:
/// every user gets unlimited searches, no paywall and no ad slot.
/// Flip `enabled` once the lifetime product is approved in App Store Connect.
enum Monetization {
    static let enabled = false

    /// Non-consumable, one-time unlock. Must match the product in App Store Connect.
    static let lifetimeProductID = "com.didisd.SunnySideApp.lifetime"

    /// Free tier: this many "Find my seat" taps per calendar day.
    static let freeSearchesPerDay = 1

    /// Whether free users see the ad slot (house banner now; ad network later).
    static let adsForFreeUsers = true
}
