import Foundation
import SwiftData

@Model
final class PayCycle {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date
    var nominalEndDate: Date
    var incomeMinor: Int64
    var rolloverMinor: Int64
    var savingsReserveMinor: Int64
    var currencyCode: String
    var isPartialCycle: Bool
    var isClosed: Bool
    var closedLeftMinor: Int64?
    var closedTotalSpentMinor: Int64?
    var closedBillsReservedMinor: Int64?
    var createdAt: Date
    var closedAt: Date?

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        nominalEndDate: Date? = nil,
        incomeMinor: Int64,
        rolloverMinor: Int64 = 0,
        savingsReserveMinor: Int64 = 0,
        currencyCode: String,
        isPartialCycle: Bool = false,
        isClosed: Bool = false,
        closedLeftMinor: Int64? = nil,
        closedTotalSpentMinor: Int64? = nil,
        closedBillsReservedMinor: Int64? = nil,
        createdAt: Date = .now,
        closedAt: Date? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.nominalEndDate = nominalEndDate ?? endDate
        self.incomeMinor = max(0, incomeMinor)
        self.rolloverMinor = rolloverMinor
        self.savingsReserveMinor = max(0, savingsReserveMinor)
        self.currencyCode = currencyCode.uppercased()
        self.isPartialCycle = isPartialCycle
        self.isClosed = isClosed
        self.closedLeftMinor = closedLeftMinor
        self.closedTotalSpentMinor = closedTotalSpentMinor
        self.closedBillsReservedMinor = closedBillsReservedMinor
        self.createdAt = createdAt
        self.closedAt = closedAt
    }
}
