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

    /// Station names repeat only when the snapshot mixes several stations.
    private var showsStationPerRow: Bool {
        Set(directions.map { $0.stationName ?? entry.stationName }).count > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppMetrics.spacingS) {
            if entry.isCityUnsupported {
                unsupportedCityState
                    .frame(maxHeight: .infinity, alignment: .center)
            } else {
                if !showsStationPerRow {
                    stationTitle(entry.stationName)
                }

                if directions.isEmpty {
                    emptyState
                        .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(directions.enumerated()), id: \.offset) { _, direction in
                            arrivalRow(direction)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(AppTheme.pageBackground, for: .widget)
    }

    private func stationTitle(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: AppMetrics.spacingXS) {
            Text(name)
                .font(.subheadline.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)

            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("最近车站，\(name)")
    }

    private func arrivalRow(_ direction: StationDirectionSnapshot) -> some View {
        let station = direction.stationName ?? entry.stationName

        return HStack(alignment: .center, spacing: AppMetrics.spacingS) {
            LineMark(lineName: direction.lineName, diameter: 24)

            VStack(alignment: .leading, spacing: 1) {
                if showsStationPerRow {
                    Text(station)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text(direction.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            countdown(for: direction)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: direction, station: station))
    }

    @ViewBuilder
    private func countdown(for direction: StationDirectionSnapshot) -> some View {
        switch direction.remainingMinutes(at: entry.date) {
        case nil:
            Text("末班已过")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
                .fixedSize()
        case 0:
            Text("即将")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.urgentText)
                .lineLimit(1)
                .fixedSize()
        case let value?:
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(value)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .fontDesign(.rounded)
                Text("分")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(AppTheme.action)
            .fixedSize()
        }
    }

    private func accessibilityLabel(for direction: StationDirectionSnapshot,
                                    station: String) -> String {
        let minutes = direction.remainingMinutes(at: entry.date)
        let timing: String
        switch minutes {
        case nil: timing = "末班已过"
        case 0: timing = "即将到站"
        case let value?: timing = "\(value) 分钟"
        }
        return "\(station)，\(direction.lineName)，往 \(direction.name)，\(timing)"
    }

    private var unsupportedCityState: some View {
        VStack(alignment: .leading, spacing: AppMetrics.spacingXS) {
            Image(systemName: "map")
                .font(.title3)
                .foregroundStyle(AppTheme.action)
            Text("当前城市暂不支持")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
            Text("目前只收录了北京地铁")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("当前城市暂不支持，目前只收录了北京地铁")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppMetrics.spacingXS) {
            Image(systemName: "location.slash")
                .font(.title3)
                .foregroundStyle(AppTheme.action)
            Text("打开 App 开启定位")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
