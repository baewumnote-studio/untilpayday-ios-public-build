import Foundation
import SwiftData

@MainActor
enum BillOccurrenceEngine {
    static func ensureOccurrences(
        for cycle: PayCycle,
        templates: [BillTemplate],
        existing: [BillOccurrence],
        context: ModelContext,
        calendar: Calendar = .current
    ) {
        for template in templates where template.isActive && template.recurrence != .none {
            let dates = occurrenceDates(for: template, from: cycle.startDate, to: cycle.endDate, calendar: calendar)
            for dueDate in dates {
                let nominal = calendar.startOfDay(for: dueDate)
                let duplicate = existing.contains {
                    $0.templateID == template.id && calendar.isDate($0.nominalDueDate, inSameDayAs: nominal)
                }
                guard !duplicate else { continue }
                context.insert(BillOccurrence(
                    templateID: template.id,
                    originalCycleID: cycle.id,
                    nameSnapshot: template.name,
                    plannedAmountMinor: template.amountMinor,
                    currencyCode: template.currencyCode,
                    dueDate: nominal,
                    nominalDueDate: nominal
                ))
            }
        }
        try? context.save()
    }

    static func occurrenceDates(
        for template: BillTemplate,
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        guard let anchor = template.anchorDate else { return [] }
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        var results: [Date] = []

        switch template.recurrence {
        case .none:
            return []
        case .weekly, .biweekly:
            let step = template.recurrence == .weekly ? 7 : 14
            var current = calendar.startOfDay(for: anchor)
            while current < startDay {
                current = calendar.date(byAdding: .day, value: step, to: current) ?? endDay
            }
            while current < endDay {
                results.append(current)
                current = calendar.date(byAdding: .day, value: step, to: current) ?? endDay
            }
        case .monthly:
            var monthCursor = startDay
            while monthCursor < endDay {
                let requested = template.dayOfMonth ?? calendar.component(.day, from: anchor)
                if let range = calendar.range(of: .day, in: .month, for: monthCursor),
                   let candidate = calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: monthCursor),
                    month: calendar.component(.month, from: monthCursor),
                    day: template.useLastDay ? range.count : min(requested, range.count)
                   )) {
                    let normalized = calendar.startOfDay(for: candidate)
                    if normalized >= startDay && normalized < endDay { results.append(normalized) }
                }
                monthCursor = calendar.date(byAdding: .month, value: 1, to: monthCursor) ?? endDay
            }
        case .yearly:
            let requestedMonth = template.monthOfYear ?? calendar.component(.month, from: anchor)
            let requestedDay = template.dayOfMonth ?? calendar.component(.day, from: anchor)
            var year = calendar.component(.year, from: startDay)
            let finalYear = calendar.component(.year, from: endDay) + 1
            while year <= finalYear {
                if let monthDate = calendar.date(from: DateComponents(year: year, month: requestedMonth, day: 1)),
                   let range = calendar.range(of: .day, in: .month, for: monthDate),
                   let candidate = calendar.date(from: DateComponents(year: year, month: requestedMonth, day: template.useLastDay ? range.count : min(requestedDay, range.count))) {
                    let normalized = calendar.startOfDay(for: candidate)
                    if normalized >= startDay && normalized < endDay { results.append(normalized) }
                }
                year += 1
            }
        }
        return results.sorted()
    }
}
