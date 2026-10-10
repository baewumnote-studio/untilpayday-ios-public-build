import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetSnapshotStore {
    static func save(_ snapshot: SharedWidgetSnapshot) {
        WidgetSnapshotCodec.save(snapshot)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func clear() {
        WidgetSnapshotCodec.clear()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func load() -> SharedWidgetSnapshot? {
        WidgetSnapshotCodec.load()
    }
}
