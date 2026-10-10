import SwiftUI

struct SafeTodayCard: View {
    let state: TodayViewState

    @ScaledMetric(relativeTo: .title)
    private var amountSize: CGFloat = 36

    private var cardBackground: Color {
        if state.isShort { return AppColor.dangerSoft }
        if state.isOverTodayPace { return AppColor.warningSoft }
        return AppColor.safeSoft
    }

    private var stateColor: Color {
        if state.isShort { return AppColor.danger }
        if state.isOverTodayPace { return AppColor.warning }
        return AppColor.safeStrong
    }

    private var paceProgress: Double {
        guard state.dailyPaceMinor > 0 else { return 0 }
        let spent = Double(max(0, state.todayFlexibleSpentMinor))
        let pace = Double(state.dailyPaceMinor)
        return min(1, max(0, spent / pace))
    }

    var body: some View {
        SurfaceCard(
            background: cardBackground,
            padding: AppSpacing.lg,
            cornerRadius: AppRadius.card
        ) {
            if state.isShort {
                shortageContent
            } else {
                safeTodayContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("safeTodayCard")
    }

    private var accessibilityLabel: String {
        if state.isShort { return String(localized: "Budget shortfall") }
        if state.isOverTodayPace { return String(localized: "Safe spending today") }
        return String(localized: "Safe spending today")
    }

    private var accessibilityValue: String {
        if state.isShort {
            return String(localized: "Short by \(MoneyFormatter.string(minorUnits: state.shortByMinor, currencyCode: state.currencyCode)) before payday")
        }
        if state.isOverTodayPace {
            return String(localized: "Zero available today. Over today’s pace by \(MoneyFormatter.string(minorUnits: state.overTodayPaceMinor, currencyCode: state.currencyCode))")
        }
        return String(localized: "\(MoneyFormatter.string(minorUnits: state.safeTodayMinor, currencyCode: state.currencyCode)) available today. \(MoneyFormatter.string(minorUnits: state.todayFlexibleSpentMinor, currencyCode: state.currencyCode)) spent today")
    }

    private var safeTodayContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                SectionEyebrow(text: "SAFE TODAY")
                Spacer()
                if !state.isOverTodayPace {
                    Label("On pace", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.safeStrong)
                        .labelStyle(.titleAndIcon)
                }
            }

            Text(MoneyFormatter.string(minorUnits: state.safeTodayMinor, currencyCode: state.currencyCode))
                .font(.system(size: amountSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText(value: Double(state.safeTodayMinor)))

            Text(state.isOverTodayPace ? "for today" : (state.todayFlexibleSpentMinor > 0 ? "left to spend today" : "available today"))
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)

            if state.dailyPaceMinor > 0 {
                VStack(spacing: AppSpacing.xs) {
                    ProgressView(value: paceProgress)
                        .tint(stateColor)
                        .scaleEffect(x: 1, y: 1.8, anchor: .center)

                    HStack {
                        Text("\(MoneyFormatter.string(minorUnits: state.todayFlexibleSpentMinor, currencyCode: state.currencyCode)) spent today")
                        Spacer()
                        Text(MoneyFormatter.string(minorUnits: state.dailyPaceMinor, currencyCode: state.currencyCode))
                    }
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .monospacedDigit()
                }
                .padding(.top, AppSpacing.xxs)
            }

            if state.isOverTodayPace {
                Divider().overlay(AppColor.line)

                Label(
                    "Over today's pace by \(MoneyFormatter.string(minorUnits: state.overTodayPaceMinor, currencyCode: state.currencyCode))",
                    systemImage: "exclamationmark.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.warning)

                Text("Your remaining money will be redistributed tomorrow.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    private var shortageContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionEyebrow(text: "SHORT BY")

            Text(MoneyFormatter.string(minorUnits: state.shortByMinor, currencyCode: state.currencyCode))
                .font(.system(size: amountSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("before payday")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)

            Label("Review upcoming bills or add income.", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppColor.danger)
        }
    }
}
