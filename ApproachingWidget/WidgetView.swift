//
//  WidgetView.swift
//  ApproachingWidget
//

import SwiftUI
import WidgetKit

struct WidgetView: View {
    var entry: StationEntry

    var body: some View {
        VStack(spacing: 6) {
            Text("🚇")
                .font(.title2)
            Text(entry.stationName)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(entry.date, format: .dateTime.hour().minute())
                .font(.title3)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
