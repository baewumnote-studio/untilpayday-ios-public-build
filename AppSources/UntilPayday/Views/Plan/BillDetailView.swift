import SwiftUI
import SwiftData

struct BillDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let bill: BillOccurrence
    let cycle: PayCycle

    @State private var showMarkPaid = false
    @State private var showEdit = false
    @State private var showSkipConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(bill.nameSnapshot)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.textPrimary)

                    Text(statusText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusColor)
                }

                SurfaceCard {
                    VStack(spacing: AppSpacing.md) {
                        detailRow("Due", value: bill.dueDate.formatted(.dateTime.month(.abbreviated).day().year()))
                        detailRow("Planned", value: MoneyFormatter.string(minorUnits: bill.plannedAmountMinor, currencyCode: bill.currencyCode))

                        if let actual = bill.actualAmountMinor {
                            detailRow("Actual", value: MoneyFormatter.string(minorUnits: actual, currencyCode: bill.currencyCode))
                        }
                    }
                }

                if bill.status == .pending {
                    VStack(spacing: AppSpacing.sm) {
                        Button("Mark as paid") { showMarkPaid = true }
                            .buttonStyle(PrimaryButtonStyle())

                        Button("Edit bill") { showEdit = true }
                            .buttonStyle(SecondaryButtonStyle())

                        Button("Skip this bill", role: .destructive) {
                            showSkipConfirmation = true
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColor.background)
        .navigationTitle("Bill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showMarkPaid) {
            NavigationStack {
                MarkBillPaidView(bill: bill, currencyCode: bill.currencyCode) { amount in
                    try CycleManager.markBillPaid(
                        bill,
                        actualAmountMinor: amount,
                        cycle: cycle,
                        context: modelContext
                    )
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                EditBillView(bill: bill)
            }
        }
        .confirmationDialog(
            "Skip this bill?",
            isPresented: $showSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button("Skip bill", role: .destructive) {
                do {
                    try CycleManager.skipBill(bill, context: modelContext)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Skipped bills are no longer reserved from Safe Today.")
        }
        .alert(
            "Couldn’t update this bill",
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

    private func detailRow(_ title: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var statusText: String {
        switch bill.status {
        case .pending: String(localized: "Pending")
        case .paid: String(localized: "Paid")
        case .skipped: String(localized: "Skipped")
        }
    }

    private var statusColor: Color {
        switch bill.status {
        case .pending: AppColor.warning
        case .paid: AppColor.safeStrong
        case .skipped: AppColor.textSecondary
        }
    }
}
