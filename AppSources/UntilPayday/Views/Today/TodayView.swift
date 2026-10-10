import SwiftUI
import SwiftData
import UntilPaydayCore

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppRouter.self) private var router

    @Query(sort: \PayCycle.startDate, order: .reverse) private var cycles: [PayCycle]
    @Query(sort: \BudgetTransaction.transactionDate, order: .reverse) private var transactions: [BudgetTransaction]
    @Query(sort: \BillOccurrence.dueDate) private var bills: [BillOccurrence]
    @Query private var templates: [BillTemplate]

    let settings: AppSettingsModel

    @State private var selectedBill: BillOccurrence?
    @State private var showPaydaySheet = false
    @State private var now = Date.now

    private var activeCycle: PayCycle? {
        cycles.first(where: { !$0.isClosed })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let cycle = activeCycle {
                    let budget = BudgetSnapshotFactory.make(
                        cycle: cycle,
                        transactions: transactions,
                        bills: bills,
                        now: now
                    )
                    let state = TodayStateBuilder.make(
                        cycle: cycle,
                        budget: budget,
                        now: now
                    )

                    LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
                        paydayHeader(state)

                        if state.isPaydayReady {
                            PaydayBanner(
                                currencyCode: state.currencyCode,
                                leftoverMinor: state.previousCycleLeftoverMinor,
                                onStartNewCycle: { showPaydaySheet = true }
                            )
                        }

                        MoneyHeroCard(
                            amountMinor: state.visibleLeftUntilPaydayMinor,
                            currencyCode: state.currencyCode
                        )

                        SafeTodayCard(state: state)

                        upcomingBills(state: state)

                        actionButtons
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.xs)
                    .padding(.bottom, AppSpacing.xxxl)
                    .task(id: state.leftUntilPaydayMinor) {
                        syncWidget(cycle: cycle, budget: budget)
                    }
                    .task(id: cycle.endDate.timeIntervalSinceReferenceDate) {
                        syncWidget(cycle: cycle, budget: budget)
                    }
                    .animation(
                        reduceMotion ? nil : .snappy(duration: 0.28),
                        value: state.leftUntilPaydayMinor
                    )
                    .animation(
                        reduceMotion ? nil : .snappy(duration: 0.28),
                        value: state.safeTodayMinor
                    )
                } else {
                    ContentUnavailableView(
                        "No active pay cycle",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Start a new cycle to see your Safe Today amount.")
                    )
                    .padding(.top, 80)
                }
            }
            .background(AppColor.background)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: Binding(
            get: { router.showAddExpense },
            set: { router.showAddExpense = $0 }
        )) {
            if let cycle = activeCycle {
                NavigationStack {
                    AddTransactionView(cycle: cycle, type: .expense)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { router.showAddIncome },
            set: { router.showAddIncome = $0 }
        )) {
            if let cycle = activeCycle {
                NavigationStack {
                    AddTransactionView(cycle: cycle, type: .extraIncome)
                }
            }
        }
        .sheet(item: $selectedBill) { bill in
            if let cycle = activeCycle {
                NavigationStack {
                    MarkBillPaidView(
                        bill: bill,
                        currencyCode: bill.currencyCode
                    ) { amount in
                        try CycleManager.markBillPaid(
                            bill,
                            actualAmountMinor: amount,
                            cycle: cycle,
                            context: modelContext
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showPaydaySheet) {
            if let cycle = activeCycle {
                PaydaySheet(
                    cycle: cycle,
                    settings: settings,
                    templates: templates,
                    occurrences: bills
                )
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = .now
            }
        }
        .task {
            while !Task.isCancelled {
                let next = DateHelpers.nextMidnight(after: now)
                let delay = max(1, next.timeIntervalSinceNow + 1)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { break }
                now = .now
            }
        }
    }

    private func paydayHeader(_ state: TodayViewState) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "calendar")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColor.accent)
                .frame(width: 42, height: 42)
                .background(AppColor.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(state.isPaydayReady ? "Payday is here" : "\(daysRemainingText(state.daysRemaining)) until payday")
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)

                Text(state.nextPayday, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(paydayAccessibilityLabel(state))
        .accessibilityIdentifier("paydaySummary")
    }

    @ViewBuilder
    private func upcomingBills(state: TodayViewState) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionEyebrow(text: "UPCOMING")
                Spacer()

                if !state.upcomingBills.isEmpty {
                    Button("See all") {
                        router.selectedTab = .plan
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.accent)
                }
            }

            if state.upcomingBills.isEmpty {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("No bills before payday")
                            .font(.headline)
                            .foregroundStyle(AppColor.textPrimary)

                        Text("Add upcoming bills and we'll keep that money out of your daily spending amount.")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)

                        Button("Add a bill") {
                            router.selectedTab = .plan
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.accent)
                        .padding(.top, AppSpacing.xxs)
                    }
                }
            } else {
                SurfaceCard(padding: AppSpacing.md) {
                    VStack(spacing: 0) {
                        ForEach(Array(state.upcomingBills.enumerated()), id: \.element.id) { index, row in
                            Button {
                                selectedBill = bills.first(where: { $0.id == row.id && $0.status == .pending })
                            } label: {
                                UpcomingBillRowView(bill: row)
                            }
                            .buttonStyle(.plain)

                            if index < state.upcomingBills.count - 1 {
                                Divider().overlay(AppColor.line)
                            }
                        }
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: AppSpacing.sm) {
            Button {
                router.showAddExpense = true
            } label: {
                Label("Add expense", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                router.showAddIncome = true
            } label: {
                Label("Add income", systemImage: "arrow.down.circle")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func paydayAccessibilityLabel(_ state: TodayViewState) -> String {
        if state.isPaydayReady {
            return String(localized: "Payday is here")
        }
        let date = state.nextPayday.formatted(date: .long, time: .omitted)
        return String(localized: "\(daysRemainingText(state.daysRemaining)) until payday. Next payday \(date)")
    }

    private func daysRemainingText(_ days: Int) -> String {
        if days == 1 { return String(localized: "1 day") }
        return String(localized: "\(max(0, days)) days")
    }

    private func syncWidget(cycle: PayCycle, budget: CycleBudgetViewModel) {
        WidgetSnapshotStore.save(.init(
            freeNowMinor: budget.snapshot.leftUntilPaydayMinor,
            todayFlexibleSpentMinor: budget.spentTodayMinor,
            currencyCode: cycle.currencyCode,
            nextPayday: cycle.endDate,
            generatedAt: .now
        ))
    }
}
