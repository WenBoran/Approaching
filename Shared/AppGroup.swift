//
//  AppGroup.swift
//  Approaching
//
//  Reads/writes the shared snapshot in the App Group UserDefaults.
//  The app writes; the widget reads.
//

import Foundation

struct StationSnapshot {
    let stationName: String
    let latitude: Double
    let longitude: Double
    let lastUpdate: Date
}

enum AppGroupStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupID)
    }

    static func save(stationName: String,
                     latitude: Double,
                     longitude: Double,
                     date: Date = Date()) {
        guard let defaults else { return }
        defaults.set(stationName, forKey: StorageKey.nearestStation)
        defaults.set(latitude, forKey: StorageKey.latitude)
        defaults.set(longitude, forKey: StorageKey.longitude)
        defaults.set(date.timeIntervalSince1970, forKey: StorageKey.lastUpdateTime)
    }

    static func load() -> StationSnapshot? {
        guard let defaults,
              let name = defaults.string(forKey: StorageKey.nearestStation) else {
            return nil
        }
        return StationSnapshot(
            stationName: name,
            latitude: defaults.double(forKey: StorageKey.latitude),
            longitude: defaults.double(forKey: StorageKey.longitude),
            lastUpdate: Date(timeIntervalSince1970: defaults.double(forKey: StorageKey.lastUpdateTime))
        )
    }
}
