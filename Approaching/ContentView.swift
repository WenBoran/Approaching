//
//  ContentView.swift
//  Approaching
//
//  Created by wenboran on 2026/7/31.
//

import CoreLocation
import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.pageBackground)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Approaching")
                            .font(.headline.weight(.bold))
                            .fontDesign(.rounded)
                            .foregroundStyle(AppTheme.action)
                    }

                    if canRefreshLocation {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                refreshLocation()
                            } label: {
                                Image(systemName: "location")
                                    .font(.body.weight(.semibold))
                                    .frame(width: AppMetrics.tapTarget, height: AppMetrics.tapTarget)
                            }
                            .accessibilityLabel("刷新定位")
                            .accessibilityHint("重新查找附近车站")
                        }
                    }
                }
                .toolbarBackground(AppTheme.pageBackground, for: .navigationBar)
                .tint(AppTheme.action)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            permissionView
        case .authorizedWhenInUse, .authorizedAlways:
            if let status = locationManager.nearestStationStatus {
                if status.isCitySupported {
                    NearestStationStatusView(
                        status: status,
                        address: locationManager.currentAddress
                    )
                } else {
                    unsupportedCityView
                }
            } else {
                loadingView
            }
        case .denied, .restricted:
            deniedView
        @unknown default:
            EmptyView()
        }
    }

    private var canRefreshLocation: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    private var permissionView: some View {
        StatusView(
            icon: "location.fill",
            title: "找到离你最近的地铁站",
            message: "位置仅用于在本地站点库中计算距离",
            actionTitle: "允许定位",
            action: locationManager.requestPermission
        )
    }

    private var loadingView: some View {
        VStack(spacing: AppMetrics.spacingL) {
            ProgressView()
                .controlSize(.large)
                .tint(AppTheme.action)
            VStack(spacing: AppMetrics.spacingXS) {
                Text("正在查找附近车站")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
                Text("正在读取你附近的地铁线路")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(AppMetrics.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unsupportedCityView: some View {
        StatusView(
            icon: "map",
            title: "当前城市暂不支持",
            message: "目前只收录了北京地铁的时刻表，离你最近的车站超过 50 公里",
            actionTitle: "重新定位",
            action: refreshLocation
        )
    }

    private var deniedView: some View {        StatusView(
            icon: "location.slash.fill",
            title: "定位服务已关闭",
            message: "请在系统设置中允许 Approaching 使用位置",
            actionTitle: "打开设置",
            isUrgent: true,
            action: openSettings
        )
    }

    private func refreshLocation() {
        locationManager.requestPermission()
        locationManager.refreshLocation()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct StatusView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    var isUrgent = false
    let action: () -> Void

    var body: some View {
        VStack(spacing: AppMetrics.spacingXL) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(isUrgent ? AppTheme.urgentText : AppTheme.onAction)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
                        .fill(isUrgent ? AppTheme.urgentSurface : AppTheme.action)
                )

            VStack(spacing: AppMetrics.spacingS) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button(action: action) {
                Text(actionTitle)
                    .font(.body.weight(.bold))
                    .foregroundStyle(AppTheme.onAction)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AppMetrics.tapTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.action)
        }
        .padding(AppMetrics.spacingXL)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NearestStationStatusView: View {
    let status: NearestStationStatus
    let address: String?
    @State private var favorites = AppGroupStore.favoriteDirections()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: currentMinuteStart, by: 60)) { context in
            ScrollView {
                LazyVStack(spacing: AppMetrics.spacingL) {
                    stationCard

                    VStack(alignment: .leading, spacing: AppMetrics.spacingM) {
                        sectionHeader

                        if status.lines.isEmpty {
                            emptyCard
                        } else {
                            ForEach(status.lines) { line in
                                lineCard(line, at: context.date)
                            }
                        }
                    }

                    Label("班次来自本地时刻表，仅供参考", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.top, AppMetrics.spacingXS)
                }
                .frame(maxWidth: AppMetrics.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppMetrics.spacingL)
                .padding(.vertical, AppMetrics.spacingL)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.pageBackground)
        }
    }

    private var currentMinuteStart: Date {
        Calendar.current.dateInterval(of: .minute, for: Date())?.start ?? Date()
    }

    private var stationCard: some View {
        VStack(alignment: .leading, spacing: AppMetrics.spacingL) {
            HStack {
                Label("最近车站", systemImage: "location.fill")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                Spacer()
                Text(status.formattedDistance)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .padding(.horizontal, AppMetrics.spacingS)
                    .padding(.vertical, AppMetrics.spacingXS)
                    .background(AppTheme.onAction.opacity(0.16), in: Capsule())
            }

            Text(status.stationName)
                .font(.largeTitle.weight(.bold))
                .fontDesign(.rounded)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            HStack(spacing: AppMetrics.spacingS) {
                Image(systemName: "mappin.and.ellipse")
                Text(address ?? "当前位置")
                    .lineLimit(2)
            }
            .font(.caption)
            .opacity(0.86)
        }
        .foregroundStyle(AppTheme.onAction)
        .padding(AppMetrics.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
                .fill(AppTheme.stationSurface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("最近车站，\(status.stationName)，距离 \(status.formattedDistance)，\(address ?? "当前位置")")
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("即将到站")
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
        }
        .padding(.horizontal, AppMetrics.spacingXS)
    }

    private var emptyCard: some View {
        AppCard {
            Label("当前时段暂无可用班次", systemImage: "calendar.badge.exclamationmark")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func lineCard(_ line: LineArrivals, at referenceDate: Date) -> some View {
        AppCard {
            HStack(spacing: AppMetrics.spacingS) {
                LineBadge(lineName: line.lineName)
                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(Array(line.directions.enumerated()), id: \.element.id) { index, direction in
                    directionRow(direction, on: line, at: referenceDate)
                    if index < line.directions.count - 1 {
                        Divider()
                            .overlay(AppTheme.separator)
                    }
                }
            }
        }
    }

    private func directionRow(_ direction: DirectionArrival,
                              on line: LineArrivals,
                              at referenceDate: Date) -> some View {
        let favorite = favoriteKey(line: line, direction: direction)
        let isFavorite = favorites.contains(favorite)

        return ArrivalRow(
            lineName: line.lineName,
            directionName: direction.directionName,
            minutes: direction.remainingMinutes(at: referenceDate),
            isFavorite: isFavorite,
            showsLineBadge: false
        ) {
            Button {
                toggleFavorite(favorite, line: line, direction: direction, at: referenceDate)
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isFavorite ? AppTheme.urgentText : AppTheme.secondaryText)
                    .frame(width: AppMetrics.tapTarget, height: AppMetrics.tapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isFavorite ? "取消优先显示" : "优先显示此方向")
            .accessibilityHint("收藏的方向会优先显示在桌面组件中")
        }
    }

    private func toggleFavorite(_ favorite: FavoriteDirection,
                               line: LineArrivals,
                               direction: DirectionArrival,
                               at referenceDate: Date) {
        let update = {
            let selected = StationService.toggleFavorite(
                station: status,
                line: line,
                direction: direction,
                now: referenceDate
            )
            if selected {
                favorites.insert(favorite)
            } else {
                favorites.remove(favorite)
            }
        }
        if reduceMotion {
            update()
        } else {
            withAnimation(.easeInOut(duration: 0.2), update)
        }
    }

    private func favoriteKey(line: LineArrivals,
                             direction: DirectionArrival) -> FavoriteDirection {
        FavoriteDirection(
            city: status.city,
            stationName: status.stationName,
            lineName: line.lineName,
            directionName: direction.directionName
        )
    }
}
