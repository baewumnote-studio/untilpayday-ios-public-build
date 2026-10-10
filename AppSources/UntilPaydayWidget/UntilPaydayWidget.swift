import WidgetKit
import SwiftUI

@main
struct UntilPaydayWidgetBundle: WidgetBundle {
    var body: some Widget {
        PaydayLeftWidget()
    }
}

struct PaydayLeftWidget: Widget {
    let kind = "PaydayLeftWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PaydayTimelineProvider()) { entry in
            PaydayWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetContainerBackground()
                }
        }
        .configurationDisplayName("Payday Left")
        .description("See what’s left and what you can safely spend today.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

private struct WidgetContainerBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            Color(red: 23 / 255, green: 33 / 255, blue: 49 / 255)
        } else {
            Color(red: 246 / 255, green: 249 / 255, blue: 254 / 255)
        }
    }
}
