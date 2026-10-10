import Foundation

enum CurrencyMetadata {
    static let supportedCodes = ["USD", "CAD", "GBP", "AUD", "EUR", "JPY", "KRW"]

    static func displayName(for code: String, locale: Locale = .current) -> String {
        let normalized = code.uppercased()
        let localized = locale.localizedString(forCurrencyCode: normalized)
        if let localized, !localized.isEmpty {
            return "\(normalized) — \(localized)"
        }
        return normalized
    }

    static func fractionDigits(for code: String) -> Int {
        SharedCurrencyRules.fractionDigits(for: code)
    }
}
