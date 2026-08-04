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
                        HStack(spacing: AppMetrics.spacingS) {
                            ApproachingMark()
                                .frame(width: 24, height: 24)
                            Text("Approaching")
                                .font(.headline)
                                .foregroundStyle(AppTheme.primaryText)
                        }
                    }

                    if canRefreshLocation {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                refreshLocation()
                            } label: {
                                Image(systemName: "location")
                                    .frame(width: 30, height: 30)
                            }
                            .accessibilityLabel("刷新定位")
                        }
                    }
                }
                .toolbarBackground(AppTheme.pageBackground, for: .navigationBar)
                .tint(AppTheme.accent)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            permissionView
        case .authorizedWhenInUse, .authorizedAlways:
            if let status = locationManager.nearestStationStatus {
                NearestStationStatusView(
                    status: status,
                    address: locationManager.currentAddress
                )
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
        ContentUnavailableView {
            ApproachingMark()
                .frame(width: 64, height: 64)
                .padding(.bottom, AppMetrics.spacingS)
            Text("找到离你最近的地铁站")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
        } description: {
            Text("位置仅用于在本地站点库中计算距离")
                .foregroundStyle(AppTheme.secondaryText)
        } actions: {
            Button("允许定位") {
                locationManager.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var loadingView: some View {
        VStack(spacing: AppMetrics.spacingL) {
            ApproachingMark()
                .frame(width: 56, height: 56)
            ProgressView()
                .controlSize(.large)
                .tint(AppTheme.accent)
            Text("正在查找附近车站")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deniedView: some View {
        ContentUnavailableView {
            Label("定位服务已关闭", systemImage: "location.slash")
                .foregroundStyle(AppTheme.primaryText)
        } description: {
            Text("请在系统设置中允许 Approaching 使用位置")
                .foregroundStyle(AppTheme.secondaryText)
        } actions: {
            Button("打开设置") {
                openSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
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

private struct NearestStationStatusView: View {
    let status: NearestStationStatus
    let address: String?
    @State private var favorites = AppGroupStore.favoriteDirections()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: currentMinuteStart, by: 60)) { context in
            ScrollView {
                VStack(spacing: AppMetrics.spacingL) {
                    stationCard

                    if status.lines.isEmpty {
                        emptyCard
                    } else {
                        ForEach(status.lines) { line in
                            lineCard(line, at: context.date)
                        }
                    }

                    Text("班次来自本地时刻表，仅供参考")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.top, AppMetrics.spacingXS)
                }
                .padding(.horizontal, AppMetrics.spacingL)
                .padding(.vertical, AppMetrics.spacingL)
            }
            .background(AppTheme.pageBackground)
        }
    }

    private var currentMinuteStart: Date {
        Calendar.current.dateInterval(of: .minute, for: Date())?.start ?? Date()
    }

    private var stationCard: some View {
        AppCard {
            Text("最近车站")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .textCase(.uppercase)

            Text(status.stationName)
                .font(.largeTitle.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            VStack(alignment: .leading, spacing: AppMetrics.spacingS) {
                Label(address ?? "当前位置", systemImage: "location.fill")
                    .lineLimit(2)
                Label(status.formattedDistance, systemImage: "figure.walk")
            }
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
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
                Text("\(line.directions.count) 个方向")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
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
                    .foregroundStyle(isFavorite ? AppTheme.urgent : AppTheme.secondaryText)
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
