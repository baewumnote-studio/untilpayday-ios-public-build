import Foundation

enum WidgetSharedConfig {
    static var appGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
            ?? "group.com.example.untilpayday.shared"
    }

    static let snapshotKey = "widget.snapshot.v1"
}

struct SharedWidgetSnapshot: Codable, Equatable {
    var freeNowMinor: Int64
    var todayFlexibleSpentMinor: Int64
    var currencyCode: String
    var nextPayday: Date
    var generatedAt: Date
}

enum WidgetSnapshotCodec {
    static func load() -> SharedWidgetSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: WidgetSharedConfig.appGroupID),
            let data = defaults.data(forKey: WidgetSharedConfig.snapshotKey)
        else { return nil }

        return try? JSONDecoder().decode(SharedWidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: SharedWidgetSnapshot) {
        guard
            let data = try? JSONEncoder().encode(snapshot),
            let defaults = UserDefaults(suiteName: WidgetSharedConfig.appGroupID)
        else { return }

        defaults.set(data, forKey: WidgetSharedConfig.snapshotKey)
    }

    static func clear() {
        UserDefaults(suiteName: WidgetSharedConfig.appGroupID)?
            .removeObject(forKey: WidgetSharedConfig.snapshotKey)
    }
}
