import SwiftUI

struct PaydayBanner: View {
    let currencyCode: String
    let leftoverMinor: Int64
    let onStartNewCycle: () -> Void

    var body: some View {
        SurfaceCard(background: AppColor.accentSoft) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("It's payday", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)

                Text("Your last cycle is ready to close.")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)

                if leftoverMinor != 0 {
                    Text("Previous balance: \(MoneyFormatter.string(minorUnits: leftoverMinor, currencyCode: currencyCode))")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppColor.textSecondary)
                }

                Button("Start new pay cycle", action: onStartNewCycle)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, AppSpacing.xxs)
            }
        }
    }
}
