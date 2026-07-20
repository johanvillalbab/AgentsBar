import SwiftUI
import WidgetKit

@main
struct AgentsBarWidgetBundle: WidgetBundle {
    var body: some Widget {
        AgentsBarSwitcherWidget()
        AgentsBarUsageWidget()
        AgentsBarHistoryWidget()
        AgentsBarCompactWidget()
        AgentsBarBurnDownWidget()
        AgentsBarCombinedBurnDownWidget()
    }
}

struct AgentsBarSwitcherWidget: Widget {
    private let kind = "AgentsBarSwitcherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: self.kind,
            provider: AgentsBarSwitcherTimelineProvider())
        { entry in
            AgentsBarSwitcherWidgetView(entry: entry)
        }
        .configurationDisplayName("AgentsBar Switcher")
        .description("Usage widget with a provider switcher.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct AgentsBarUsageWidget: Widget {
    private let kind = "AgentsBarUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: ProviderSelectionIntent.self,
            provider: AgentsBarTimelineProvider())
        { entry in
            AgentsBarUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("AgentsBar Usage")
        .description("Session and weekly usage with credits and costs.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct AgentsBarHistoryWidget: Widget {
    private let kind = "AgentsBarHistoryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: ProviderSelectionIntent.self,
            provider: AgentsBarTimelineProvider())
        { entry in
            AgentsBarHistoryWidgetView(entry: entry)
        }
        .configurationDisplayName("AgentsBar History")
        .description("Usage history chart with recent totals.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct AgentsBarCompactWidget: Widget {
    private let kind = "AgentsBarCompactWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: CompactMetricSelectionIntent.self,
            provider: AgentsBarCompactTimelineProvider())
        { entry in
            AgentsBarCompactWidgetView(entry: entry)
        }
        .configurationDisplayName("AgentsBar Metric")
        .description("Compact widget for credits or cost.")
        .supportedFamilies([.systemSmall])
    }
}

struct AgentsBarBurnDownWidget: Widget {
    private let kind = "AgentsBarBurnDownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: BurnDownSelectionIntent.self,
            provider: BurnDownTimelineProvider())
        { entry in
            BurnDownWidgetView(entry: entry)
        }
        .configurationDisplayName("AgentsBar Burn Down")
        .description("Remaining budget compared with an ideal steady burn rate.")
        .supportedFamilies([.systemMedium])
    }
}

struct AgentsBarCombinedBurnDownWidget: Widget {
    private let kind = "AgentsBarCombinedBurnDownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: BurnProviderSelectionIntent.self,
            provider: CombinedBurnDownTimelineProvider())
        { entry in
            CombinedBurnDownWidgetView(entry: entry)
        }
        .configurationDisplayName("AgentsBar Burn Down (Combined)")
        .description("Session and weekly burn-down charts in one tile.")
        .supportedFamilies([.systemMedium])
    }
}
