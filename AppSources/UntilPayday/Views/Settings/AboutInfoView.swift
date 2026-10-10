import SwiftUI

enum AboutInfoPage {
    case howItWorks
    case disclaimer
    case privacy

    var title: LocalizedStringKey {
        switch self {
        case .howItWorks: "How Payday Left works"
        case .disclaimer: "Planning disclaimer"
        case .privacy: "Privacy policy"
        }
    }
}

struct AboutInfoView: View {
    let page: AboutInfoPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                switch page {
                case .howItWorks:
                    howItWorks
                case .disclaimer:
                    disclaimer
                case .privacy:
                    privacy
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColor.background)
        .navigationTitle(page.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var howItWorks: some View {
        Group {
            infoBlock(
                "1. Start with the money available for this pay cycle",
                "Payday Left does not read a bank account. You enter the money you have available and your next payday."
            )

            infoBlock(
                "2. Protect savings and upcoming bills",
                "Savings and pending bills due before payday are taken out before Safe Today is calculated."
            )

            infoBlock(
                "3. Use Safe Today as your daily pace",
                "Safe Today shows how much flexible money remains for today. Money you do not use is redistributed across the remaining days."
            )

            infoBlock(
                "4. Start a new cycle on payday",
                "Close the previous cycle, choose what cash carries forward, then begin again with the new paycheck."
            )
        }
    }

    private var disclaimer: some View {
        Group {
            infoBlock(
                "Planning estimates",
                "Payday Left provides estimates based only on the information you enter. It does not guarantee that a purchase is affordable."
            )

            infoBlock(
                "No financial services",
                "The app does not access, hold, move, invest, lend, or pay money. It does not provide investment, credit, tax, or legal advice."
            )

            infoBlock(
                "Keep your entries current",
                "Safe Today is only as accurate as the income, expenses, bills, savings, and payday dates stored in the app."
            )
        }
    }

    private var privacy: some View {
        Group {
            infoBlock(
                "Budget records",
                "Your paycheck amounts, expenses, bill names, notes, and savings values are stored locally on your device. Payday Left has no custom account system or budgeting server."
            )

            infoBlock(
                "Advertising",
                "The app may use Google Mobile Ads and Google User Messaging Platform. Advertising services may process device or advertising information according to your region and privacy choices. Payday Left does not intentionally send your budget records to the advertising SDK."
            )

            infoBlock(
                "Deleting your data",
                "You can erase locally stored budgeting data from Settings using Reset all data."
            )

            Text("A hosted privacy-policy URL is still required before App Store release. The hosted version must match this behavior and the final advertising configuration.")
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private func infoBlock(_ heading: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(heading)
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
            Text(body)
                .font(.body)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
