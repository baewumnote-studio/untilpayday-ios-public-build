import Foundation

/// Overflow-safe arithmetic for persisted integer money values.
/// Real-world user input is constrained long before these limits, but the
/// calculation layer still avoids trapping if imported/corrupted data is extreme.
public enum MinorUnitMath {
    public static func adding(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let result = lhs.addingReportingOverflow(rhs)
        guard result.overflow else { return result.partialValue }
        return rhs >= 0 ? .max : .min
    }

    public static func subtracting(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let result = lhs.subtractingReportingOverflow(rhs)
        guard result.overflow else { return result.partialValue }
        return rhs >= 0 ? .min : .max
    }

    public static func sum<S: Sequence>(_ values: S) -> Int64 where S.Element == Int64 {
        values.reduce(Int64(0), adding)
    }

    public static func absolute(_ value: Int64) -> Int64 {
        value == .min ? .max : Swift.abs(value)
    }
}
