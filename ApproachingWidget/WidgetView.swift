//
//  WidgetView.swift
//  ApproachingWidget
//

import Foundation
import SwiftUI
import WidgetKit

struct WidgetView: View {
    var entry: StationEntry

    private var directions: [StationDirectionSnapshot] {
        Array(entry.directions.prefix(AppConstants.widgetDirectionCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppMetrics.spacingS) {
            header

            if directions.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(directions.enumerated()), id: \.element.name) { index, direction in
                        ArrivalRow(
                            lineName: direction.lineName,
                            directionName: direction.name,
                            minutes: direction.remainingMinutes(at: entry.date),
                            isFavorite: direction.isFavorite,
                            compact: true
                        )
                        .accessibilityElement(children: .combine)

                        if index < directions.count - 1 {
                            Rectangle()
                                .fill(AppTheme.separator)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(AppTheme.surface, for: .widget)
    }

    private var header: some View {
        HStack(spacing: AppMetrics.spacingXS) {
            ApproachingMark()
                .frame(width: 18, height: 18)
                .widgetAccentable()

            Text(entry.stationName)
                .font(.subheadline.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("最近车站，\(entry.stationName)")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppMetrics.spacingXS) {
            Image(systemName: "location.slash")
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
            Text("打开 App 更新位置")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
