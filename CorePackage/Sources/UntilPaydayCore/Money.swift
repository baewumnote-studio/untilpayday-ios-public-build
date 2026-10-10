import Foundation

public struct Money: Hashable, Codable, Sendable {
    public let minorUnits: Int64
    public let currencyCode: String

    public init(minorUnits: Int64, currencyCode: String) {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode.uppercased()
    }

    public static func zero(currencyCode: String) -> Money {
        Money(minorUnits: 0, currencyCode: currencyCode)
    }

    public var isNegative: Bool { minorUnits < 0 }
    public var isZero: Bool { minorUnits == 0 }

    public func adding(_ other: Money) throws -> Money {
        try validateCurrency(other)
        let result = minorUnits.addingReportingOverflow(other.minorUnits)
        guard !result.overflow else { throw MoneyError.overflow }
        return Money(minorUnits: result.partialValue, currencyCode: currencyCode)
    }

    public func subtracting(_ other: Money) throws -> Money {
        try validateCurrency(other)
        let result = minorUnits.subtractingReportingOverflow(other.minorUnits)
        guard !result.overflow else { throw MoneyError.overflow }
        return Money(minorUnits: result.partialValue, currencyCode: currencyCode)
    }

    public func negated() throws -> Money {
        guard minorUnits != .min else { throw MoneyError.overflow }
        return Money(minorUnits: -minorUnits, currencyCode: currencyCode)
    }

    private func validateCurrency(_ other: Money) throws {
        guard currencyCode == other.currencyCode else {
            throw MoneyError.currencyMismatch(expected: currencyCode, received: other.currencyCode)
        }
    }
}

public enum MoneyError: Error, Equatable, Sendable {
    case currencyMismatch(expected: String, received: String)
    case overflow
}
