import SwiftUI
import SwiftData
import Charts
import UntilPaydayCore

struct HistoryView: View {
    @Query(sort: \PayCycle.startDate, order: .reverse) private var cycles: [PayCycle]
    @Query private var transactions: [BudgetTransaction]

    private var completed: [PayCycle] {
        cycles.filter(\.isClosed)
    }

    var body: some View {
        NavigationStack {
            Group {
                if completed.isEmpty {
                    ContentUnavailableView(
                        "Your first pay cycle is underway",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Completed cycles will appear here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(completed) { cycle in
                                let cycleTransactions = transactions.filter { $0.cycleID == cycle.id }

                                NavigationLink {
                                    CycleDetailView(
                                        cycle: cycle,
                                        transactions: cycleTransactions
                                    )
                                } label: {
                                    HistoryCycleCard(
                                        cycle: cycle,
                                        transactions: cycleTransactions
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("historyCycleCard")
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.xs)
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                    .background(AppColor.background)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct HistoryCycleCard: View {
    let cycle: PayCycle
    let transactions: [BudgetTransaction]

    private var spentMinor: Int64 {
        cycle.closedTotalSpentMinor
            ?? transactions
                .filter { $0.type == .expense }
                .map(\.amountMinor)
                .reduce(Int64(0), MinorUnitMath.adding)
    }

    private var flexibleSpentMinor: Int64 {
        transactions
            .filter { $0.type == .expense && $0.linkedBillOccurrenceID == nil }
            .map(\.amountMinor)
            .reduce(Int64(0), MinorUnitMath.adding)
    }

    private var dayCount: Int64 {
        let value = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: cycle.startDate),
            to: Calendar.current.startOfDay(for: cycle.endDate)
        ).day ?? 0
        return Int64(max(1, value))
    }

    private var dailyAverageMinor: Int64 {
        flexibleSpentMinor / dayCount
    }

    private var leftMinor: Int64 {
        cycle.closedLeftMinor ?? 0
    }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .center) {
                    Text("\(cycle.startDate.formatted(.dateTime.month(.abbreviated).day())) – \(cycle.endDate.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)

                    Spacer()

                    if cycle.isPartialCycle {
                        Text("Partial cycle")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColor.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColor.accentSoft)
                            .clipShape(Capsule())
                    }
                }

                metricRow("Started", MinorUnitMath.adding(cycle.incomeMinor, cycle.rolloverMinor))
                metricRow("Spent", spentMinor)
                metricRow("Protected", cycle.savingsReserveMinor)
                metricRow("Daily flexible avg.", dailyAverageMinor)

                Divider().overlay(AppColor.line)

                HStack {
                    Text(leftMinor >= 0 ? "Left" : "Short")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    Text(MoneyFormatter.string(minorUnits: safeAbs(leftMinor), currencyCode: cycle.currencyCode))
                        .font(.body.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(leftMinor >= 0 ? AppColor.safeStrong : AppColor.danger)
                }
            }
        }
    }

    private func metricRow(_ label: LocalizedStringKey, _ value: Int64) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
            Text(MoneyFormatter.string(minorUnits: value, currencyCode: cycle.currencyCode))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(AppColor.textPrimary)
        }
    }

    private func safeAbs(_ value: Int64) -> Int64 {
        value == .min ? .max : abs(value)
    }
}

private struct DailySpendPoint: Identifiable {
    let date: Date
    let amount: Int64
    var id: Date { date }
}

private struct CategorySpendRow: Identifiable {
    let category: ExpenseCategory
    let amount: Int64
    var id: String { category.rawValue }
}

struct CycleDetailView: View {
    @Environment(AppRouter.self) private var router

    let cycle: PayCycle
    let transactions: [BudgetTransaction]

    private var expenses: [BudgetTransaction] {
        transactions.filter { $0.type == .expense }
    }

    private var totalSpent: Int64 {
        cycle.closedTotalSpentMinor
            ?? expenses.map(\.amountMinor).reduce(Int64(0), MinorUnitMath.adding)
    }

    private var flexibleSpent: Int64 {
        expenses
            .filter { $0.linkedBillOccurrenceID == nil }
            .map(\.amountMinor)
            .reduce(Int64(0), MinorUnitMath.adding)
    }

    private var dayCount: Int64 {
        let value = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: cycle.startDate),
            to: Calendar.current.startOfDay(for: cycle.endDate)
        ).day ?? 0
        return Int64(max(1, value))
    }

    private var averageFlexibleSpend: Int64 {
        flexibleSpent / dayCount
    }

    private var leftMinor: Int64 {
        cycle.closedLeftMinor ?? 0
    }

    private var points: [DailySpendPoint] {
        let grouped = Dictionary(grouping: expenses) {
            Calendar.current.startOfDay(for: $0.transactionDate)
        }
        return grouped
            .map { date, values in
                DailySpendPoint(
                    date: date,
                    amount: values.map(\.amountMinor).reduce(Int64(0), MinorUnitMath.adding)
                )
            }
            .sorted { $0.date < $1.date }
    }

    private var categoryRows: [CategorySpendRow] {
        let grouped = Dictionary(grouping: expenses, by: \.category)
        return grouped
            .map { category, values in
                CategorySpendRow(
                    category: category,
                    amount: values.map(\.amountMinor).reduce(Int64(0), MinorUnitMath.adding)
                )
            }
            .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
                headerCard
                summaryCard

                if !points.isEmpty {
                    dailyChart
                }

                if !categoryRows.isEmpty {
                    categoryBreakdown
                }

                transactionList
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .background(AppColor.background)
        .navigationTitle("Pay cycle")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            router.markHistoryMeaningfulUse()
        }
    }

    private var headerCard: some View {
        SurfaceCard(cornerRadius: AppRadius.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                SectionEyebrow(text: leftMinor >= 0 ? "LEFT OVER" : "SHORT BY")

                Text(MoneyFormatter.string(minorUnits: safeAbs(leftMinor), currencyCode: cycle.currencyCode))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(leftMinor >= 0 ? AppColor.textPrimary : AppColor.danger)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("\(cycle.startDate.formatted(.dateTime.month(.abbreviated).day())) – \(cycle.endDate.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionEyebrow(text: "SUMMARY")
            SurfaceCard {
                VStack(spacing: AppSpacing.md) {
                    summaryRow("Started", MinorUnitMath.adding(cycle.incomeMinor, cycle.rolloverMinor))
                    summaryRow("Spent", totalSpent)
                    summaryRow("Protected", cycle.savingsReserveMinor)
                    summaryRow("Average/day", averageFlexibleSpend)
                }
            }
        }
    }

    private var dailyChart: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionEyebrow(text: "DAILY SPENDING")

            SurfaceCard {
                Chart(points) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Spent", point.amount)
                    )
                    .foregroundStyle(AppColor.accent)
                    .cornerRadius(3)
                }
                .chartYAxis(.hidden)
                .frame(height: 170)
                .accessibilityLabel("Daily spending chart")
            }
        }
    }

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionEyebrow(text: "BY CATEGORY")

            SurfaceCard(padding: AppSpacing.md) {
                VStack(spacing: 0) {
                    ForEach(Array(categoryRows.enumerated()), id: \.element.id) { index, row in
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: row.category.symbol)
                                .foregroundStyle(AppColor.textSecondary)
                                .frame(width: 26)

                            Text(row.category.title)
                                .foregroundStyle(AppColor.textPrimary)

                            Spacer()

                            Text(MoneyFormatter.string(minorUnits: row.amount, currencyCode: cycle.currencyCode))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .padding(.vertical, AppSpacing.sm)

                        if index < categoryRows.count - 1 {
                            Divider().overlay(AppColor.line)
                        }
                    }
                }
            }
        }
    }

    private var transactionList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionEyebrow(text: "TRANSACTIONS")

            if transactions.isEmpty {
                SurfaceCard {
                    Text("No transactions in this cycle.")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                }
            } else {
                SurfaceCard(padding: AppSpacing.md) {
                    VStack(spacing: 0) {
                        let sorted = transactions.sorted { $0.transactionDate > $1.transactionDate }

                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, transaction in
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: transaction.type == .expense ? transaction.category.symbol : "arrow.down.circle.fill")
                                    .foregroundStyle(transaction.type == .expense ? AppColor.textSecondary : AppColor.safeStrong)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    Text(transactionTitle(transaction))
                                        .foregroundStyle(AppColor.textPrimary)

                                    Text(transaction.transactionDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(AppColor.textSecondary)
                                }

                                Spacer(minLength: AppSpacing.sm)

                                Text((transaction.type == .expense ? "−" : "+") + MoneyFormatter.string(minorUnits: transaction.amountMinor, currencyCode: cycle.currencyCode))
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundStyle(transaction.type == .expense ? AppColor.textPrimary : AppColor.safeStrong)
                            }
                            .padding(.vertical, AppSpacing.sm)

                            if index < sorted.count - 1 {
                                Divider().overlay(AppColor.line)
                            }
                        }
                    }
                }
            }
        }
    }

    private func summaryRow(_ label: LocalizedStringKey, _ value: Int64) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
            Text(MoneyFormatter.string(minorUnits: value, currencyCode: cycle.currencyCode))
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(AppColor.textPrimary)
        }
        .font(.subheadline)
    }

    private func transactionTitle(_ transaction: BudgetTransaction) -> String {
        if !transaction.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return transaction.note
        }
        if transaction.type == .extraIncome {
            return String(localized: "Extra income")
        }
        return transaction.category.title
    }

    private func safeAbs(_ value: Int64) -> Int64 {
        value == .min ? .max : abs(value)
    }
}
