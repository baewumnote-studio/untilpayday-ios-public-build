import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(
                isEnabled
                    ? (configuration.isPressed ? AppColor.accentPressed : AppColor.accent)
                    : AppColor.textSecondary.opacity(0.30)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .shadow(
                color: isEnabled ? AppColor.accent.opacity(0.18) : .clear,
                radius: 8,
                x: 0,
                y: 4
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? AppColor.accent : AppColor.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(configuration.isPressed ? AppColor.accentSoft : AppColor.surface)
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .stroke(AppColor.line, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
