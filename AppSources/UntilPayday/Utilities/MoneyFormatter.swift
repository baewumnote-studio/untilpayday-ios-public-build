import Foundation

enum MoneyFormatter {
    static func fractionDigits(for currencyCode: String, locale: Locale = .current) -> Int {
        CurrencyMetadata.fractionDigits(for: currencyCode)
    }

    static func currencySymbol(for currencyCode: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode.uppercased()
        formatter.minimumFractionDigits = fractionDigits(for: currencyCode, locale: locale)
        formatter.maximumFractionDigits = fractionDigits(for: currencyCode, locale: locale)
        return formatter.currencySymbol ?? currencyCode.uppercased()
    }

    static func string(
        minorUnits: Int64,
        currencyCode: String,
        locale: Locale = .current
    ) -> String {
        let digits = fractionDigits(for: currencyCode, locale: locale)
        let decimal = decimalFromMinorUnits(minorUnits, fractionDigits: digits)

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode.uppercased()
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits

        return formatter.string(from: NSDecimalNumber(decimal: decimal))
            ?? "\(currencyCode.uppercased()) \(NSDecimalNumber(decimal: decimal).stringValue)"
    }

    static func compactString(
        minorUnits: Int64,
        currencyCode: String,
        locale: Locale = .current
    ) -> String {
        string(minorUnits: minorUnits, currencyCode: currencyCode, locale: locale)
    }

    static func inputString(
        minorUnits: Int64,
        currencyCode: String,
        locale: Locale = .current
    ) -> String {
        let digits = fractionDigits(for: currencyCode, locale: locale)
        let decimal = decimalFromMinorUnits(minorUnits, fractionDigits: digits)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits

        return formatter.string(from: NSDecimalNumber(decimal: decimal))
            ?? NSDecimalNumber(decimal: decimal).stringValue
    }

    static func parseMinorUnits(
        _ text: String,
        currencyCode: String,
        locale: Locale = .current
    ) -> Int64? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.generatesDecimalNumbers = true
        formatter.usesGroupingSeparator = true

        if let number = formatter.number(from: cleaned) as? NSDecimalNumber {
            return decimalToMinor(
                number.decimalValue,
                currencyCode: currencyCode,
                locale: locale
            )
        }

        // Accept a decimal separator that differs from the current keyboard/region.
        let normalized = cleaned
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")

        guard let decimal = Decimal(
            string: normalized,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            return nil
        }

        return decimalToMinor(
            decimal,
            currencyCode: currencyCode,
            locale: locale
        )
    }

    private static func decimalFromMinorUnits(
        _ minorUnits: Int64,
        fractionDigits: Int
    ) -> Decimal {
        var divisor = Decimal(1)
        if fractionDigits > 0 {
            for _ in 0..<fractionDigits {
                divisor *= 10
            }
        }
        return Decimal(minorUnits) / divisor
    }

    private static func decimalToMinor(
        _ decimal: Decimal,
        currencyCode: String,
        locale: Locale
    ) -> Int64? {
        let digits = fractionDigits(for: currencyCode, locale: locale)
        var value = decimal
        var multiplier = Decimal(1)

        if digits > 0 {
            for _ in 0..<digits {
                multiplier *= 10
            }
        }

        value *= multiplier

        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)

        let number = NSDecimalNumber(decimal: rounded)
        let max = NSDecimalNumber(value: Int64.max)
        let min = NSDecimalNumber(value: Int64.min)

        guard number.compare(max) != .orderedDescending,
              number.compare(min) != .orderedAscending else {
            return nil
        }

        return number.int64Value
    }
}
