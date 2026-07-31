//
//  ApproachingWidget.swift
//  ApproachingWidget
//

import SwiftUI
import WidgetKit

struct ApproachingWidget: Widget {
    let kind = AppConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Approaching")
        .description("显示最近的地铁站与当前时间")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct ApproachingWidgetBundle: WidgetBundle {
    var body: some Widget {
        ApproachingWidget()
    }
}
