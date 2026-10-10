import SwiftUI

struct MoneyEntryField: View {
    let title: LocalizedStringKey
    let currencyCode: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
            HStack(spacing: AppSpacing.sm) {
                Text(currencyCode)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityLabel(title)
            }
            .padding(.horizontal, AppSpacing.lg)
            .frame(minHeight: 54)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .stroke(AppColor.line, lineWidth: 1)
            }
        }
    }
}
