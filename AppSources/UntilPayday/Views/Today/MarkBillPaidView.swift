import SwiftUI

struct MarkBillPaidView: View {
    @Environment(\.dismiss) private var dismiss

    let bill: BillOccurrence
    let currencyCode: String
    let onConfirm: (Int64) throws -> Void

    @State private var amountText: String
    @State private var errorMessage: String?
    @FocusState private var amountFocused: Bool

    init(
        bill: BillOccurrence,
        currencyCode: String,
        onConfirm: @escaping (Int64) throws -> Void
    ) {
        self.bill = bill
        self.currencyCode = currencyCode
        self.onConfirm = onConfirm
        _amountText = State(
            initialValue: MoneyFormatter.inputString(
                minorUnits: bill.plannedAmountMinor,
                currencyCode: currencyCode
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(bill.nameSnapshot)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.textPrimary)

                    Text("Due \(bill.dueDate.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                }

                SurfaceCard {
                    HStack {
                        Text("Planned amount")
                            .foregroundStyle(AppColor.textSecondary)
                        Spacer()
                        Text(MoneyFormatter.string(minorUnits: bill.plannedAmountMinor, currencyCode: currencyCode))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(AppColor.textPrimary)
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionEyebrow(text: "ACTUAL AMOUNT")
                    LargeMoneyInput(
                        currencyCode: currencyCode,
                        text: $amountText,
                        focus: $amountFocused
                    )
                }

                SurfaceCard(background: AppColor.accentSoft) {
                    Text("The planned amount is already reserved. If the actual amount changed, only the difference affects what’s left until payday.")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Confirm payment") {
                    confirm()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .background(AppColor.background)
        .navigationTitle("Mark as paid")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                amountFocused = true
            }
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

    private func confirm() {
        guard let amount = MoneyFormatter.parseMinorUnits(amountText, currencyCode: currencyCode), amount >= 0 else {
            errorMessage = String(localized: "Enter a valid amount.")
            return
        }

        do {
            try onConfirm(amount)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
