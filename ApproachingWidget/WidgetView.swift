//
//  WidgetView.swift
//  ApproachingWidget
//

import Foundation
import SwiftUI
import WidgetKit

struct WidgetView: View {
    var entry: StationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "tram.fill")
                    .font(.subheadline)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)

                Text(entry.stationName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 0)
            }

            Spacer(minLength: 8)

            if entry.directions.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Image(systemName: "location.slash")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("打开 App 更新位置")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entry.directions.prefix(2).enumerated()), id: \.element.name) { index, direction in
                        directionRow(direction)
                        if index < min(entry.directions.count, 2) - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func directionRow(_ direction: StationDirectionSnapshot) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("开往")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(direction.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 2)

            if let minutes = direction.remainingMinutes(at: entry.date) {
                if minutes == 0 {
                    Text("即将到站")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(minutes)")
                            .font(.title3.weight(.semibold).monospacedDigit())
                        Text("分")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(minutes <= 2 ? .red : .primary)
                }
            } else {
                Text("今日结束")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: 42)
        .accessibilityElement(children: .combine)
    }

}
