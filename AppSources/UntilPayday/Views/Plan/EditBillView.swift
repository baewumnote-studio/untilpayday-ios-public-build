import SwiftUI
import SwiftData

struct EditBillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let bill: BillOccurrence

    @Query private var templates: [BillTemplate]

    @State private var name = ""
    @State private var amountText = ""
    @State private var dueDate = Date.now
    @State private var errorMessage: String?

    private var template: BillTemplate? {
        guard let templateID = bill.templateID else { return nil }
        return templates.first(where: { $0.id == templateID })
    }

    var body: some View {
        Form {
            Section("Bill") {
                TextField("Name", text: $name)

                MoneyEntryField(
                    title: "Planned amount",
                    currencyCode: bill.currencyCode,
                    text: $amountText
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
            }

            if template != nil {
                Section {
                    Text("Name and amount changes also apply to future repeats. The due-date change updates this occurrence only.")
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
        .navigationTitle("Edit bill")
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
            name = bill.nameSnapshot
            amountText = MoneyFormatter.inputString(minorUnits: bill.plannedAmountMinor, currencyCode: bill.currencyCode)
            dueDate = bill.dueDate
        }
        .alert(
            "Check this bill",
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
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = String(localized: "Give the bill a name.")
            return
        }

        guard let amount = MoneyFormatter.parseMinorUnits(amountText, currencyCode: bill.currencyCode), amount > 0 else {
            errorMessage = String(localized: "Enter an amount greater than zero.")
            return
        }

        bill.nameSnapshot = trimmed
        bill.plannedAmountMinor = amount
        bill.dueDate = Calendar.current.startOfDay(for: dueDate)
        bill.nominalDueDate = bill.dueDate

        if let template {
            template.name = trimmed
            template.amountMinor = amount
            template.updatedAt = .now
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = String(localized: "Couldn’t save this bill. Try again.")
        }
    }
}
