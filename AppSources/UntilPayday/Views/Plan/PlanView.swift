import SwiftUI
import SwiftData
import UntilPaydayCore

struct PlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PayCycle.startDate, order: .reverse) private var cycles: [PayCycle]
    @Query private var transactions: [BudgetTransaction]
    @Query(sort: \BillOccurrence.dueDate) private var bills: [BillOccurrence]
    @Query(sort: \BillTemplate.name) private var templates: [BillTemplate]

    let settings: AppSettingsModel

    @State private var showAddBill = false
    @State private var selectedBill: BillOccurrence?
    @State private var segment: PlanSegment = .upcoming

    private enum PlanSegment: String, CaseIterable, Identifiable {
        case upcoming = "Upcoming"
        case recurring = "Recurring"
        var id: String { rawValue }
    }

    private var activeCycle: PayCycle? {
        cycles.first(where: { !$0.isClosed })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let cycle = activeCycle {
                    let vm = BudgetSnapshotFactory.make(
                        cycle: cycle,
                        transactions: transactions,
                        bills: bills
                    )

                    LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
                        cycleSummary(cycle: cycle, vm: vm)

                        Picker("Plan section", selection: $segment) {
                            ForEach(PlanSegment.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("planSegmentedControl")
                        .accessibilityLabel("Plan section")

                        switch segment {
                        case .upcoming:
                            billSection(cycle: cycle)
                        case .recurring:
                            recurringSection
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.xs)
                    .padding(.bottom, AppSpacing.xxxl)
                } else {
                    ContentUnavailableView(
                        "No active plan",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Start a pay cycle first.")
                    )
                    .padding(.top, 80)
                }
            }
            .background(AppColor.background)
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddBill = true } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .frame(width: 32, height: 32)
                            .background(AppColor.accentSoft)
                            .clipShape(Circle())
                    }
                    .foregroundStyle(AppColor.accent)
                    .accessibilityLabel("Add bill")
                }
            }
        }
        .sheet(isPresented: $showAddBill) {
            if let cycle = activeCycle {
                NavigationStack {
                    AddBillView(cycle: cycle, currencyCode: cycle.currencyCode)
                }
            }
        }
        .sheet(item: $selectedBill) { bill in
            if let cycle = activeCycle {
                NavigationStack {
                    BillDetailView(bill: bill, cycle: cycle)
                }
            }
        }
        .task(id: activeCycle?.id) {
            guard let cycle = activeCycle else { return }
            BillOccurrenceEngine.ensureOccurrences(
                for: cycle,
                templates: templates,
                existing: bills,
                context: modelContext
            )
        }
    }

    private func cycleSummary(cycle: PayCycle, vm: CycleBudgetViewModel) -> some View {
        SurfaceCard(background: AppColor.accentSoft, cornerRadius: AppRadius.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        SectionEyebrow(text: "CURRENT CYCLE")
                        Text("\(cycle.startDate.formatted(.dateTime.month(.abbreviated).day())) – \(cycle.endDate.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColor.accent)
                        .frame(width: 42, height: 42)
                        .background(AppColor.surface.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(vm.snapshot.leftUntilPaydayMinor >= 0 ? "LEFT UNTIL PAYDAY" : "SHORT BY")
                        .font(.caption2.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(AppColor.textSecondary)

                    Text(
                        MoneyFormatter.string(
                            minorUnits: absSafely(vm.snapshot.leftUntilPaydayMinor),
                            currencyCode: cycle.currencyCode
                        )
                    )
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(vm.snapshot.leftUntilPaydayMinor >= 0 ? AppColor.textPrimary : AppColor.danger)
                }

                HStack(spacing: AppSpacing.sm) {
                    compactMetric(
                        title: "Spent",
                        value: vm.totalSpentMinor,
                        currency: cycle.currencyCode
                    )
                    compactMetric(
                        title: "Bills reserved",
                        value: vm.pendingBillsMinor,
                        currency: cycle.currencyCode
                    )
                    compactMetric(
                        title: "Savings",
                        value: cycle.savingsReserveMinor,
                        currency: cycle.currencyCode
                    )
                }
            }
        }
    }

    private func compactMetric(title: LocalizedStringKey, value: Int64, currency: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(1)
            Text(MoneyFormatter.string(minorUnits: value, currencyCode: currency))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(AppColor.surface.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
    }

    private func billSection(cycle: PayCycle) -> some View {
        let cutoff = Calendar.current.startOfDay(for: cycle.endDate)
        let relevant = bills.filter { bill in
            let isPendingBeforePayday = bill.status == .pending && Calendar.current.startOfDay(for: bill.dueDate) < cutoff
            let wasPaidInThisCycle = bill.status == .paid && transactions.contains { transaction in
                transaction.cycleID == cycle.id && transaction.linkedBillOccurrenceID == bill.id
            }
            return isPendingBeforePayday || wasPaidInThisCycle
        }
        .sorted { $0.dueDate < $1.dueDate }

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionEyebrow(text: "BILLS BEFORE PAYDAY")
                Spacer()
                Text("\(relevant.filter { $0.status == .pending }.count) pending")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }

            if relevant.isEmpty {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Label("No bills before payday", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(AppColor.safeStrong)

                        Text("Add bills you need to cover before payday. Pending bills are reserved before Safe Today is calculated.")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)

                        Button("Add a bill") { showAddBill = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.accent)
                            .padding(.top, AppSpacing.xxs)
                    }
                }
            } else {
                SurfaceCard(padding: AppSpacing.md) {
                    VStack(spacing: 0) {
                        ForEach(Array(relevant.enumerated()), id: \.element.id) { index, bill in
                            Button {
                                selectedBill = bill
                            } label: {
                                BillRow(bill: bill)
                            }
                            .buttonStyle(.plain)

                            if index < relevant.count - 1 {
                                Divider().overlay(AppColor.line)
                            }
                        }
                    }
                }
            }
        }
    }

    private var recurringSection: some View {
        let activeTemplates = templates.filter(\.isActive)

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionEyebrow(text: "RECURRING BILLS")
                Spacer()
                Text("\(activeTemplates.count) active")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }

            if activeTemplates.isEmpty {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("No recurring bills yet")
                            .font(.headline)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("Create a recurring bill and future occurrences will be generated automatically.")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)
                        Button("Add a recurring bill") { showAddBill = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.accent)
                            .padding(.top, AppSpacing.xxs)
                    }
                }
            } else {
                SurfaceCard(padding: AppSpacing.md) {
                    VStack(spacing: 0) {
                        ForEach(Array(activeTemplates.enumerated()), id: \.element.id) { index, template in
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppColor.accent)
                                    .frame(width: 34, height: 34)
                                    .background(AppColor.accentSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    Text(template.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(AppColor.textPrimary)
                                    Text(template.recurrence.title)
                                        .font(.caption)
                                        .foregroundStyle(AppColor.textSecondary)
                                }

                                Spacer()

                                Text(MoneyFormatter.string(minorUnits: template.amountMinor, currencyCode: template.currencyCode))
                                    .font(.body.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(AppColor.textPrimary)
                            }
                            .padding(.vertical, AppSpacing.sm)

                            if index < activeTemplates.count - 1 {
                                Divider().overlay(AppColor.line)
                            }
                        }
                    }
                }
            }
        }
    }

    private func absSafely(_ value: Int64) -> Int64 {
        value == .min ? .max : abs(value)
    }
}
