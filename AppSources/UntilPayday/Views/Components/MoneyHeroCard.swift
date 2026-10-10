import SwiftUI

struct MoneyHeroCard: View {
    let amountMinor: Int64
    let currencyCode: String

    @ScaledMetric(relativeTo: .largeTitle)
    private var amountSize: CGFloat = 46

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("LEFT UNTIL PAYDAY")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.88))

            Text(MoneyFormatter.string(minorUnits: amountMinor, currencyCode: currencyCode))
                .font(.system(size: amountSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.60)
                .contentTransition(.numericText(value: Double(amountMinor)))

            Text("Bills and savings already covered")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(
                colors: [AppColor.heroStart, AppColor.heroEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous))
        .shadow(color: AppColor.safe.opacity(0.20), radius: 18, x: 0, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Money left until payday")
        .accessibilityValue(MoneyFormatter.string(minorUnits: amountMinor, currencyCode: currencyCode))
        .accessibilityIdentifier("leftUntilPaydayHero")
    }
}
