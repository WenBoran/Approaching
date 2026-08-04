//
//  ContentView.swift
//  Approaching
//
//  Created by wenboran on 2026/7/31.
//

import SwiftUI
import CoreLocation
import UIKit

struct ContentView: View {
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusContent

                    if let status = locationManager.nearestStationStatus {
                        NearestStationStatusView(
                            status: status,
                            address: locationManager.currentAddress
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Approaching")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("刷新定位", systemImage: "location") {
                        refreshLocation()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            ContentUnavailableView {
                Label("需要位置权限", systemImage: "location.circle")
            } description: {
                Text("用于查找距离当前位置最近的地铁站")
            } actions: {
                Button("允许定位") {
                    locationManager.requestPermission()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 56)
        case .authorizedWhenInUse, .authorizedAlways:
            if locationManager.nearestStationStatus == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在查找附近地铁站")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 72)
            }
        case .denied, .restricted:
            ContentUnavailableView {
                Label("定位服务已关闭", systemImage: "location.slash")
            } description: {
                Text("请在系统设置中允许 Approaching 使用位置")
            } actions: {
                Button("打开设置") {
                    openSettings()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 56)
        @unknown default:
            EmptyView()
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

    var body: some View {
        TimelineView(.periodic(from: currentMinuteStart, by: 60)) { context in
            VStack(alignment: .leading, spacing: 20) {
                stationHeader
                arrivalPanel(at: context.date)
            }
        }
    }

    private var currentMinuteStart: Date {
        Calendar.current.dateInterval(of: .minute, for: Date())?.start ?? Date()
    }

    private var stationHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近的地铁站")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(status.stationName)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(status.lineName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .lineLimit(1)
            }

            Label(address ?? "当前位置", systemImage: "location.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 16) {
                Label(status.formattedDistance, systemImage: "figure.walk")
                Label {
                    Text(status.updatedAt, style: .relative)
                } icon: {
                    Image(systemName: "clock")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private func arrivalPanel(at referenceDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("下一班车")
                    .font(.headline)
                Spacer()
                Text("本地时刻表")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .padding(.leading, 16)

            if status.directions.isEmpty {
                Label("当前时段暂无可用班次", systemImage: "calendar.badge.exclamationmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            } else {
                ForEach(Array(status.directions.prefix(2).enumerated()), id: \.element.id) { index, arrival in
                    arrivalRow(arrival, at: referenceDate)
                    if index < min(status.directions.count, 2) - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 8))
    }

    private func arrivalRow(_ arrival: DirectionArrival, at referenceDate: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("开往")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(arrival.directionName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if let minutes = arrival.remainingMinutes(at: referenceDate) {
                if minutes == 0 {
                    Text("即将到站")
                        .font(.headline)
                        .foregroundStyle(.red)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(minutes)")
                            .font(.title2.weight(.semibold).monospacedDigit())
                        Text("分钟")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(minutes <= 2 ? .red : .primary)
                }
            } else {
                Text("今日结束")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
