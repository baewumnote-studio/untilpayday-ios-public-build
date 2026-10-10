import SwiftUI

struct BillRow: View {
    let bill: BillOccurrence

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: statusSymbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(statusColor)
                .frame(width: 34, height: 34)
                .background(statusBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(bill.nameSnapshot)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppColor.textPrimary)

                HStack(spacing: 4) {
                    Text(bill.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                    Text("·")
                    Text(statusText)
                }
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
            }

            Spacer(minLength: AppSpacing.sm)

            Text(MoneyFormatter.string(minorUnits: bill.actualAmountMinor ?? bill.plannedAmountMinor, currencyCode: bill.currencyCode))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(AppColor.textPrimary)
        }
        .padding(.vertical, AppSpacing.sm)
        .contentShape(Rectangle())
    }

    private var statusSymbol: String {
        switch bill.status {
        case .pending: "calendar.badge.clock"
        case .paid: "checkmark"
        case .skipped: "forward.fill"
        }
    }

    private var statusColor: Color {
        switch bill.status {
        case .pending: AppColor.accent
        case .paid: AppColor.safeStrong
        case .skipped: AppColor.textSecondary
        }
    }

    private var statusBackground: Color {
        switch bill.status {
        case .pending: AppColor.accentSoft
        case .paid: AppColor.safeSoft
        case .skipped: AppColor.background
        }
    }

    private var statusText: String {
        switch bill.status {
        case .pending:
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            let due = calendar.startOfDay(for: bill.dueDate)
            let days = calendar.dateComponents([.day], from: today, to: due).day ?? 0
            switch days {
            case Int.min..<0: return String(localized: "overdue")
            case 0: return String(localized: "today")
            case 1: return String(localized: "tomorrow")
            default: return String(localized: "in \(days) days")
            }
        case .paid:
            return String(localized: "Paid")
        case .skipped:
            return String(localized: "Skipped")
        }
    }
}
