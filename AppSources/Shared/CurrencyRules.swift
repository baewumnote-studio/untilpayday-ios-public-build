import Foundation

enum SharedCurrencyRules {
    static func fractionDigits(for currencyCode: String) -> Int {
        switch currencyCode.uppercased() {
        case "JPY", "KRW":
            return 0
        default:
            return 2
        }
    }
}
