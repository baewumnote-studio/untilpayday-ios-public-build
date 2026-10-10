import SwiftUI

struct SectionEyebrow: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(0.7)
            .foregroundStyle(AppColor.textSecondary)
            .textCase(.uppercase)
    }
}
