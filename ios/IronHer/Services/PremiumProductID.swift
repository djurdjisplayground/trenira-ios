import Foundation

/// App Store Connect / local StoreKit Configuration product identifiers.
/// Must match `trenira.storekit` (scheme) and App Store Connect exactly.
enum PremiumProductID {
    static let monthly = "trenira.premium.monthly"
    static let yearly = "trenira.premium.yearly"

    static let all: Set<String> = [monthly, yearly]

    /// Display order on the paywall (yearly first = best value).
    static let ordered: [String] = [yearly, monthly]
}
