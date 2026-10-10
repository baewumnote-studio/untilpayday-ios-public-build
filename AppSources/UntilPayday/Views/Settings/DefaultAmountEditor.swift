import SwiftUI
import SwiftData

enum DefaultAmountField {
    case paycheck
    case savings

    var title: LocalizedStringKey {
        switch self {
        case .paycheck: "Default paycheck"
        case .savings: "Default savings"
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .paycheck:
            "Used as the starting suggestion when you begin a new pay cycle."
        case .savings:
            "Money protected from Safe Today by default when you begin a new pay cycle."
        }
    }
}

struct DefaultAmountEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let settings: AppSettingsModel
    let field: DefaultAmountField

    @State private var amountText = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                MoneyEntryField(
                    title: field.title,
                    currencyCode: settings.currencyCode,
                    text: $amountText
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                Text(field.explanation)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .navigationTitle(field.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            let value = field == .paycheck
                ? settings.defaultPayAmountMinor
                : settings.defaultSavingsMinor
            amountText = MoneyFormatter.inputString(
                minorUnits: value,
                currencyCode: settings.currencyCode
            )
        }
        .alert(
            "Check the amount",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save() {
        guard let amount = MoneyFormatter.parseMinorUnits(
            amountText,
            currencyCode: settings.currencyCode
        ), amount >= 0 else {
            errorMessage = String(localized: "Enter a valid amount.")
            return
        }

        switch field {
        case .paycheck:
            settings.defaultPayAmountMinor = amount
        case .savings:
            settings.defaultSavingsMinor = amount
        }
        settings.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
