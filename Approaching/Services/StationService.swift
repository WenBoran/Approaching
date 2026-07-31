//
//  StationService.swift
//  Approaching
//
//  Computes the nearest station, persists it to the App Group,
//  and asks WidgetKit to reload.
//

import Foundation
import WidgetKit

enum StationService {
    @discardableResult
    static func updateNearestStation(latitude: Double, longitude: Double) -> String? {
        guard let station = DatabaseManager.shared.nearestStation(
            latitude: latitude,
            longitude: longitude
        ) else {
            return nil
        }
        AppGroupStore.save(stationName: station.name,
                           latitude: latitude,
                           longitude: longitude)
        WidgetCenter.shared.reloadAllTimelines()
        return station.name
    }
}
