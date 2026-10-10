import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let cycle: PayCycle
    let type: TransactionType

    @State private var amountText = ""
    @State private var category: ExpenseCategory = .food
    @State private var note = ""
    @State private var date = Date.now
    @State private var errorMessage: String?
    @FocusState private var amountFocused: Bool

    private let categoryColumns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                LargeMoneyInput(
                    currencyCode: cycle.currencyCode,
                    text: $amountText,
                    focus: $amountFocused
                )

                if type == .expense {
                    categorySection
                } else {
                    SurfaceCard {
                        Label("Extra income", systemImage: "arrow.down.circle.fill")
                            .font(.headline)
                            .foregroundStyle(AppColor.safeStrong)
                    }
                }

                detailsSection

                Button(type == .expense ? "Save expense" : "Add income") {
                    save()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .background(AppColor.background)
        .navigationTitle(type == .expense ? "Add expense" : "Add income")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            date = clamp(Date.now, to: transactionDateRange)
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

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionEyebrow(text: "CATEGORY")

            LazyVGrid(columns: categoryColumns, spacing: AppSpacing.sm) {
                ForEach(ExpenseCategory.allCases) { item in
                    Button {
                        category = item
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: item.symbol)
                                .frame(width: 20)
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(category == item ? AppColor.accent : AppColor.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(category == item ? AppColor.accentSoft : AppColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                .stroke(category == item ? AppColor.accent.opacity(0.35) : AppColor.line, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionEyebrow(text: "DETAILS")

            SurfaceCard {
                VStack(spacing: AppSpacing.md) {
                    DatePicker(
                        "Date",
                        selection: $date,
                        in: transactionDateRange,
                        displayedComponents: .date
                    )

                    Divider().overlay(AppColor.line)

                    TextField("Note · optional", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
        }
    }

    private var transactionDateRange: ClosedRange<Date> {
        let lower = Calendar.current.startOfDay(for: cycle.startDate)
        let beforePayday = cycle.endDate.addingTimeInterval(-1)
        let upperCandidate = min(Date.now, beforePayday)
        let upper = max(lower, upperCandidate)
        return lower...upper
    }

    private func clamp(_ value: Date, to range: ClosedRange<Date>) -> Date {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func save() {
        guard let amount = MoneyFormatter.parseMinorUnits(amountText, currencyCode: cycle.currencyCode), amount > 0 else {
            errorMessage = String(localized: "Enter an amount greater than zero.")
            return
        }

        modelContext.insert(BudgetTransaction(
            cycleID: cycle.id,
            type: type,
            amountMinor: amount,
            category: type == .expense ? category : .other,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            transactionDate: date
        ))

        do {
            try modelContext.save()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
        } catch {
            errorMessage = String(localized: "Couldn’t save this transaction. Try again.")
        }
    }
}
