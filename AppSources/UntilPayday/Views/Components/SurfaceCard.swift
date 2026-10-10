import SwiftUI

struct SurfaceCard<Content: View>: View {
    let background: Color
    let padding: CGFloat
    let cornerRadius: CGFloat
    let shadowed: Bool
    private let content: Content

    init(
        background: Color = AppColor.surface,
        padding: CGFloat = AppSpacing.lg,
        cornerRadius: CGFloat = AppRadius.card,
        shadowed: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadowed = shadowed
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColor.line.opacity(0.75), lineWidth: 0.6)
            }
            .shadow(
                color: shadowed ? AppShadow.cardColor : .clear,
                radius: shadowed ? AppShadow.cardRadius : 0,
                x: 0,
                y: shadowed ? AppShadow.cardY : 0
            )
    }
}
