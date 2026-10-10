import SwiftUI
import UIKit

enum AppColor {
    // Visual Master v1.1: bright native-iOS palette.
    static let background = Color(lightHex: 0xF6F9FE, darkHex: 0x0D1522)
    static let surface = Color(lightHex: 0xFFFFFF, darkHex: 0x172131)
    static let surfaceRaised = Color(lightHex: 0xFFFFFF, darkHex: 0x1D2A3D)

    static let textPrimary = Color(lightHex: 0x10213E, darkHex: 0xF4F7FB)
    static let textSecondary = Color(lightHex: 0x64748B, darkHex: 0xAAB8CC)

    // Blue owns navigation, actions and selection.
    static let accent = Color(lightHex: 0x0A7AFF, darkHex: 0x63A9FF)
    static let accentPressed = Color(lightHex: 0x006CE6, darkHex: 0x8BC0FF)
    static let accentSoft = Color(lightHex: 0xEAF3FF, darkHex: 0x16304F)

    // Green is reserved for safe-to-spend / healthy budget states.
    static let safe = Color(lightHex: 0x31C66B, darkHex: 0x55DD8A)
    static let safeStrong = Color(lightHex: 0x1EAD58, darkHex: 0x6AE599)
    static let safeSoft = Color(lightHex: 0xEAF9F0, darkHex: 0x183927)

    static let warning = Color(lightHex: 0xEF8B2C, darkHex: 0xFFB45E)
    static let warningSoft = Color(lightHex: 0xFFF4E8, darkHex: 0x4A321C)
    static let danger = Color(lightHex: 0xD9535F, darkHex: 0xFF7F89)
    static let dangerSoft = Color(lightHex: 0xFFF0F2, darkHex: 0x482329)

    static let line = Color(lightHex: 0xE3EAF4, darkHex: 0x2A394E)
    static let progressTrack = Color(lightHex: 0xE6EDF6, darkHex: 0x29384C)

    static let heroStart = Color(lightHex: 0x36CB72, darkHex: 0x2FAE63)
    static let heroEnd = Color(lightHex: 0x56D98D, darkHex: 0x3BB874)
}

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

enum AppRadius {
    static let control: CGFloat = 16
    static let card: CGFloat = 20
    static let hero: CGFloat = 24
    static let compact: CGFloat = 14
}

enum AppShadow {
    static let cardColor = Color.black.opacity(0.055)
    static let cardRadius: CGFloat = 14
    static let cardY: CGFloat = 5
}

extension Color {
    init(lightHex: UInt, darkHex: UInt) {
        self.init(UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? darkHex : lightHex
            let r = Double((hex >> 16) & 0xFF) / 255
            let g = Double((hex >> 8) & 0xFF) / 255
            let b = Double(hex & 0xFF) / 255
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        })
    }
}

struct CardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let background: Color
    let shadowed: Bool

    init(
        cornerRadius: CGFloat = AppRadius.card,
        padding: CGFloat = AppSpacing.lg,
        background: Color = AppColor.surface,
        shadowed: Bool = true
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.background = background
        self.shadowed = shadowed
    }

    func body(content: Content) -> some View {
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

extension View {
    func paydayCard(
        cornerRadius: CGFloat = AppRadius.card,
        padding: CGFloat = AppSpacing.lg,
        background: Color = AppColor.surface,
        shadowed: Bool = true
    ) -> some View {
        modifier(
            CardModifier(
                cornerRadius: cornerRadius,
                padding: padding,
                background: background,
                shadowed: shadowed
            )
        )
    }
}
