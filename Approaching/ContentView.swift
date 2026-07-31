//
//  ContentView.swift
//  Approaching
//
//  Created by wenboran on 2026/7/31.
//

import SwiftUI
import CoreLocation

struct ContentView: View {
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        VStack(spacing: 16) {
            Text("🚇 Approaching")
                .font(.title2)
                .bold()

            Text(statusText)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let name = locationManager.lastStationName {
                Text("最近地铁站：\(name)")
                    .font(.headline)
            }

            Button("刷新定位") {
                locationManager.requestPermission()
                locationManager.refreshLocation()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var statusText: String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "请授权定位权限"
        case .authorizedWhenInUse, .authorizedAlways:
            return "定位已授权，请将 Widget 添加到桌面"
        case .denied, .restricted:
            return "定位权限被拒绝，请在系统设置中开启"
        @unknown default:
            return ""
        }
    }
}
