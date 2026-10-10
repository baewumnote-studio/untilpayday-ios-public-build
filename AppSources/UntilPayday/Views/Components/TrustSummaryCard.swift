import SwiftUI

struct TrustSummaryCard: View {
    var body: some View {
        SurfaceCard(background: AppColor.accentSoft, cornerRadius: AppRadius.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title3)
                        .foregroundStyle(AppColor.accent)
                        .frame(width: 40, height: 40)
                        .background(AppColor.surface.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your budget. Your device.")
                            .font(.headline)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("Simple by design.")
                            .font(.caption)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }

                trustRow("No bank connection")
                trustRow("No account required")
                trustRow("No subscription")
                trustRow("Budget records stay on your device")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("trustSummaryCard")
    }

    private func trustRow(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColor.safeStrong)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: 0)
        }
    }
}
