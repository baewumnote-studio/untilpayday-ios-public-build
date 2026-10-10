import Foundation
import SwiftData

@Model
final class BillOccurrence {
    @Attribute(.unique) var id: UUID
    var templateID: UUID?
    var originalCycleID: UUID?
    var nameSnapshot: String
    var plannedAmountMinor: Int64
    var actualAmountMinor: Int64?
    var currencyCode: String
    var dueDate: Date
    var nominalDueDate: Date
    var statusRaw: String
    var linkedTransactionID: UUID?
    var createdAt: Date
    var paidAt: Date?

    init(
        id: UUID = UUID(),
        templateID: UUID? = nil,
        originalCycleID: UUID? = nil,
        nameSnapshot: String,
        plannedAmountMinor: Int64,
        actualAmountMinor: Int64? = nil,
        currencyCode: String,
        dueDate: Date,
        nominalDueDate: Date? = nil,
        status: BillStatus = .pending,
        linkedTransactionID: UUID? = nil,
        createdAt: Date = .now,
        paidAt: Date? = nil
    ) {
        self.id = id
        self.templateID = templateID
        self.originalCycleID = originalCycleID
        self.nameSnapshot = nameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        self.plannedAmountMinor = max(0, plannedAmountMinor)
        self.actualAmountMinor = actualAmountMinor.map { max(0, $0) }
        self.currencyCode = currencyCode.uppercased()
        self.dueDate = dueDate
        self.nominalDueDate = nominalDueDate ?? dueDate
        self.statusRaw = status.rawValue
        self.linkedTransactionID = linkedTransactionID
        self.createdAt = createdAt
        self.paidAt = paidAt
    }

    var status: BillStatus {
        get { BillStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
