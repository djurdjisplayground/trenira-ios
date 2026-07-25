import Foundation
import StoreKit

/// Display helpers for StoreKit subscription products — prices and periods
/// always come from StoreKit, never hard-coded currency values.
enum SubscriptionProductFormatting {
    static func billingPeriodLabel(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else {
            return product.displayName
        }
        return periodDescription(period)
    }

    static func periodDescription(_ period: Product.SubscriptionPeriod) -> String {
        let unit: String
        switch period.unit {
        case .day:
            unit = period.value == 1 ? "day" : "days"
        case .week:
            unit = period.value == 1 ? "week" : "weeks"
        case .month:
            unit = period.value == 1 ? "month" : "months"
        case .year:
            unit = period.value == 1 ? "year" : "years"
        @unknown default:
            unit = "period"
        }
        return period.value == 1 ? unit : "\(period.value) \(unit)"
    }

    static func priceAndPeriodLine(for product: Product) -> String {
        "\(product.displayPrice) / \(billingPeriodLabel(for: product))"
    }

    static func autoRenewLine(for product: Product) -> String {
        let period = billingPeriodLabel(for: product)
        return "Auto-renews every \(period). Cancel anytime."
    }

    static func introductoryOfferLine(
        for product: Product,
        isEligible: Bool
    ) -> String? {
        guard isEligible,
              let offer = product.subscription?.introductoryOffer else {
            return nil
        }

        let duration = periodDescription(offer.period)
        switch offer.paymentMode {
        case .freeTrial:
            return "Includes a \(duration) free trial"
        case .payAsYouGo:
            return "Intro: \(offer.displayPrice) for \(duration)"
        case .payUpFront:
            return "Intro: \(offer.displayPrice) for \(duration)"
        default:
            return "Introductory offer available"
        }
    }

    static func isBestValue(_ product: Product) -> Bool {
        product.id == PremiumProductID.yearly
    }
}
