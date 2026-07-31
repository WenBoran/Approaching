//
//  ApproachingApp.swift
//  Approaching
//
//  Created by wenboran on 2026/7/31.
//

import SwiftUI

@main
struct ApproachingApp: App {
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView(locationManager: locationManager)
                .onAppear {
                    locationManager.requestPermission()
                    locationManager.refreshLocation()
                }
        }
    }
}
