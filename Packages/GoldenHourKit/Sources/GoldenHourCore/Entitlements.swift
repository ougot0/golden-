import Foundation

/// Access to paid features.
///
/// GoldenHour is sold as a paid-upfront app (no in-app purchase, no subscription, no ads), so every
/// feature is unlocked by owning the app. The app layer depends on this protocol rather than on a
/// concrete purchase mechanism so a StoreKit 2 implementation (`Product`, `Transaction.currentEntitlements`,
/// `AppTransaction`) can be added later — for example to move to a free download with a one-time unlock —
/// without touching the feature code.
public protocol EntitlementProviding: Sendable {
    var hasFullAccess: Bool { get }
}

/// Entitlements for the paid-upfront distribution model.
public struct PaidUpfrontEntitlements: EntitlementProviding {
    public init() {}
    public var hasFullAccess: Bool { true }
}
