import SwiftUI
import SwiftData

struct AddBillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let cycle: PayCycle
    let currencyCode: String

    @State private var name = ""
    @State private var amountText = ""
    @State private var dueDate = Date.now
    @State private var recurrence: BillRecurrence = .none
    @State private var useLastDay = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Bill") {
                TextField("Name", text: $name)

                MoneyEntryField(
                    title: "Planned amount",
                    currencyCode: currencyCode,
                    text: $amountText
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
            }

            Section("Repeat") {
                Picker("Repeat", selection: $recurrence) {
                    ForEach(BillRecurrence.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }

                if recurrence == .monthly {
                    Toggle("Use last day of month", isOn: $useLastDay)
                }
            }

            Section {
                Text("A pending bill due before the next payday is reserved immediately, so Safe Today won’t accidentally spend that money.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .navigationTitle("Add bill")
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
        .onChange(of: recurrence) { _, newValue in
            if newValue == .monthly, isLastDayOfMonth(dueDate) {
                useLastDay = true
            } else if newValue != .monthly {
                useLastDay = false
            }
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

        guard let amount = MoneyFormatter.parseMinorUnits(amountText, currencyCode: currencyCode), amount > 0 else {
            errorMessage = String(localized: "Enter an amount greater than zero.")
            return
        }

        var normalizedDue = Calendar.current.startOfDay(for: dueDate)
        if recurrence == .monthly, useLastDay,
           let range = Calendar.current.range(of: .day, in: .month, for: normalizedDue),
           let last = Calendar.current.date(from: DateComponents(
            year: Calendar.current.component(.year, from: normalizedDue),
            month: Calendar.current.component(.month, from: normalizedDue),
            day: range.count
           )) {
            normalizedDue = Calendar.current.startOfDay(for: last)
        }

        var templateID: UUID?

        if recurrence != .none {
            let template = BillTemplate(
                name: trimmed,
                amountMinor: amount,
                currencyCode: currencyCode,
                recurrence: recurrence,
                anchorDate: normalizedDue,
                dayOfMonth: Calendar.current.component(.day, from: normalizedDue),
                monthOfYear: Calendar.current.component(.month, from: normalizedDue),
                useLastDay: recurrence == .monthly && useLastDay
            )
            templateID = template.id
            modelContext.insert(template)
        }

        modelContext.insert(BillOccurrence(
            templateID: templateID,
            originalCycleID: cycle.id,
            nameSnapshot: trimmed,
            plannedAmountMinor: amount,
            currencyCode: currencyCode,
            dueDate: normalizedDue,
            nominalDueDate: normalizedDue
        ))

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = String(localized: "Couldn’t save this bill. Try again.")
        }
    }

    private func isLastDayOfMonth(_ date: Date) -> Bool {
        guard let range = Calendar.current.range(of: .day, in: .month, for: date) else { return false }
        return Calendar.current.component(.day, from: date) == range.count
    }
}
