import WidgetKit
import Foundation

struct PaydayWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedWidgetSnapshot?

    var computed: SharedWidgetBudgetValues? {
        guard let snapshot else { return nil }
        return WidgetBudgetCalculator.calculate(snapshot: snapshot, at: date)
    }
}

struct PaydayTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PaydayWidgetEntry {
        PaydayWidgetEntry(
            date: .now,
            snapshot: SharedWidgetSnapshot(
                freeNowMinor: 132_700,
                todayFlexibleSpentMinor: 4_800,
                currencyCode: "USD",
                nextPayday: Calendar.current.date(byAdding: .day, value: 13, to: .now) ?? .now,
                generatedAt: .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PaydayWidgetEntry) -> Void) {
        completion(PaydayWidgetEntry(date: .now, snapshot: WidgetSnapshotCodec.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PaydayWidgetEntry>) -> Void) {
        let now = Date.now
        let snapshot = WidgetSnapshotCodec.load()
        let entry = PaydayWidgetEntry(date: now, snapshot: snapshot)
        let nextMidnight = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: now)
        ) ?? now.addingTimeInterval(86_400)

        completion(
            Timeline(
                entries: [entry],
                policy: .after(nextMidnight.addingTimeInterval(5))
            )
        )
    }
}
