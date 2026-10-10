import SwiftUI

struct UpcomingBillRowView: View {
    let bill: UpcomingBillRowState

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            Image(systemName: iconName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34)
                .background(iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(bill.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppColor.textPrimary)

                HStack(spacing: 4) {
                    Text(bill.dueDate, format: .dateTime.month(.abbreviated).day())
                    Text("·")
                    Text(relativeText)
                }
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
            }

            Spacer(minLength: 12)

            Text(MoneyFormatter.string(minorUnits: bill.plannedAmountMinor, currencyCode: bill.currencyCode))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(AppColor.textPrimary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        bill.daysUntilDue < 0 ? "exclamationmark" : "calendar"
    }

    private var iconColor: Color {
        if bill.daysUntilDue < 0 { return AppColor.danger }
        if bill.daysUntilDue <= 3 { return AppColor.warning }
        return AppColor.accent
    }

    private var iconBackground: Color {
        if bill.daysUntilDue < 0 { return AppColor.dangerSoft }
        if bill.daysUntilDue <= 3 { return AppColor.warningSoft }
        return AppColor.accentSoft
    }

    private var relativeText: String {
        switch bill.daysUntilDue {
        case Int.min..<0: return String(localized: "overdue")
        case 0: return String(localized: "today")
        case 1: return String(localized: "tomorrow")
        default: return String(localized: "in \(bill.daysUntilDue) days")
        }
    }
}
