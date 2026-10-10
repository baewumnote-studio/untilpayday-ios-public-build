import SwiftUI

struct LargeMoneyInput: View {
    let currencyCode: String
    @Binding var text: String
    var focus: FocusState<Bool>.Binding? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            Text(MoneyFormatter.currencySymbol(for: currencyCode))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColor.textSecondary)

            if let focus {
                TextField("0", text: $text)
                    .focused(focus)
                    .keyboardType(.decimalPad)
                    .moneyInputStyle()
                    .accessibilityIdentifier("moneyAmountField")
            } else {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .moneyInputStyle()
                    .accessibilityIdentifier("moneyAmountField")
            }
        }
        .padding(.vertical, AppSpacing.md)
        .accessibilityElement(children: .contain)
    }
}

private extension View {
    func moneyInputStyle() -> some View {
        self
            .font(.system(size: 42, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(AppColor.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
    }
}
