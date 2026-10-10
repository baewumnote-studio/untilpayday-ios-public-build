import WidgetKit
import SwiftUI

struct PaydayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: PaydayWidgetEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, let values = entry.computed {
                content(snapshot: snapshot, values: values)
            } else {
                emptyState
            }
        }
        .widgetURL(URL(string: "untilpayday://today"))
    }

    @ViewBuilder
    private func content(snapshot: SharedWidgetSnapshot, values: SharedWidgetBudgetValues) -> some View {
        switch family {
        case .systemSmall:
            smallContent(snapshot: snapshot, values: values)

        case .systemMedium:
            mediumContent(snapshot: snapshot, values: values)

        case .accessoryRectangular:
            rectangularContent(snapshot: snapshot, values: values)

        case .accessoryCircular:
            circularContent(snapshot: snapshot, values: values)

        default:
            EmptyView()
        }
    }

    private func smallContent(snapshot: SharedWidgetSnapshot, values: SharedWidgetBudgetValues) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(values.shortByMinor > 0 ? "SHORT BY" : "SAFE TODAY")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(widgetMoney(values.shortByMinor > 0 ? values.shortByMinor : values.safeMinor, snapshot.currencyCode))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(values.shortByMinor > 0 ? WidgetPalette.danger : WidgetPalette.safe)
                        .minimumScaleFactor(0.58)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if values.isPayday {
                    Image(systemName: "sparkles")
                        .font(.headline)
                        .foregroundStyle(WidgetPalette.blue)
                } else {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(values.daysRemaining)")
                            .font(.title2.bold())
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text("days left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 4)

            if values.isPayday {
                Text("Payday is here")
                    .font(.subheadline.weight(.semibold))
                Text("Open to start a new cycle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if values.shortByMinor > 0 {
                Label("Review your plan", systemImage: "exclamationmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetPalette.danger)
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(WidgetPalette.safe)
                        .frame(width: 7, height: 7)
                    Text("On pace")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func mediumContent(snapshot: SharedWidgetSnapshot, values: SharedWidgetBudgetValues) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(values.shortByMinor > 0 ? "SHORT BY" : "LEFT UNTIL PAYDAY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(widgetMoney(values.shortByMinor > 0 ? values.shortByMinor : values.leftMinor, snapshot.currencyCode))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(values.shortByMinor > 0 ? WidgetPalette.danger : .primary)
                    .minimumScaleFactor(0.62)
                    .lineLimit(1)

                Spacer()

                Text(values.isPayday ? "Payday is here" : "\(values.daysRemaining) days until payday")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                Text("SAFE TODAY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(widgetMoney(values.safeMinor, snapshot.currencyCode))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(values.shortByMinor > 0 ? .secondary : WidgetPalette.safe)
                    .minimumScaleFactor(0.62)
                    .lineLimit(1)

                Spacer()

                if let addExpenseURL = URL(string: "untilpayday://add-expense") {
                    Link(destination: addExpenseURL) {
                        Label("Add expense", systemImage: "plus.circle.fill")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetPalette.blue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func rectangularContent(snapshot: SharedWidgetSnapshot, values: SharedWidgetBudgetValues) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(values.shortByMinor > 0 ? "Short by" : "Safe today")
                    .font(.caption2)
                Text(widgetMoney(values.shortByMinor > 0 ? values.shortByMinor : values.safeMinor, snapshot.currencyCode))
                    .font(.headline)
                    .monospacedDigit()
            }

            Spacer(minLength: 4)

            if values.isPayday {
                Text("Payday")
                    .font(.caption.weight(.semibold))
            } else {
                Text("\(values.daysRemaining)d")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
        }
    }

    private func circularContent(snapshot: SharedWidgetSnapshot, values: SharedWidgetBudgetValues) -> some View {
        VStack(spacing: 0) {
            Text(values.shortByMinor > 0 ? "SHORT" : "SAFE")
                .font(.system(size: 8, weight: .bold))
            Text(shortMoney(values.shortByMinor > 0 ? values.shortByMinor : values.safeMinor, snapshot.currencyCode))
                .font(.caption.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.5)
            Text(values.isPayday ? "PAY" : "\(values.daysRemaining)d")
                .font(.system(size: 8))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "calendar.badge.checkmark")
                .foregroundStyle(WidgetPalette.blue)
            Text("Plan to payday")
                .font(.headline)
            Text("Open Payday Left to get started.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func widgetMoney(_ minor: Int64, _ code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = .current

        let digits = SharedCurrencyRules.fractionDigits(for: code)
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        let amount = decimalAmount(minor: minor, fractionDigits: digits)
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(code) \(minor)"
    }

    private func shortMoney(_ minor: Int64, _ code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = .current
        formatter.maximumFractionDigits = 0

        let digits = MoneyDigits.fractionDigits(for: code)
        let amount = decimalAmount(minor: minor, fractionDigits: digits)
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "—"
    }

    private func decimalAmount(minor: Int64, fractionDigits: Int) -> Decimal {
        var divisor = Decimal(1)
        if fractionDigits > 0 {
            for _ in 0..<fractionDigits {
                divisor *= 10
            }
        }
        return Decimal(minor) / divisor
    }
}

private enum WidgetPalette {
    static let blue = Color(red: 10 / 255, green: 122 / 255, blue: 1)
    static let safe = Color(red: 49 / 255, green: 198 / 255, blue: 107 / 255)
    static let danger = Color(red: 217 / 255, green: 83 / 255, blue: 95 / 255)
}

private enum MoneyDigits {
    static func fractionDigits(for code: String) -> Int {
        SharedCurrencyRules.fractionDigits(for: code)
    }
}
