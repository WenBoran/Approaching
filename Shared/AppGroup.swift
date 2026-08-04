//
//  AppGroup.swift
//  Approaching
//
//  Reads/writes the shared snapshot in the App Group UserDefaults.
//  The app writes; the widget reads.
//

import Foundation

struct StationDirectionSnapshot: Codable, Equatable {
    let name: String
    let arrivalDates: [Date]

    func remainingMinutes(at referenceDate: Date) -> Int? {
        ArrivalSchedule.remainingMinutes(in: arrivalDates, at: referenceDate)
    }
}

enum ArrivalSchedule {
    static func remainingMinutes(in arrivalDates: [Date], at referenceDate: Date) -> Int? {
        let calendar = Calendar.current
        let minuteStart = calendar.dateInterval(of: .minute, for: referenceDate)?.start
            ?? referenceDate
        guard let arrivalDate = arrivalDates.first(where: { $0 >= minuteStart }) else {
            return nil
        }
        return max(0, Int(ceil(arrivalDate.timeIntervalSince(minuteStart) / 60)))
    }
}

struct StationSnapshot {
    let stationName: String
    let latitude: Double
    let longitude: Double
    let lastUpdate: Date
    let directions: [StationDirectionSnapshot]
}

enum AppGroupStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupID)
    }

    static func save(stationName: String,
                     latitude: Double,
                     longitude: Double,
                     directions: [StationDirectionSnapshot] = [],
                     date: Date = Date()) {
        guard let defaults else { return }
        defaults.set(stationName, forKey: StorageKey.nearestStation)
        defaults.set(latitude, forKey: StorageKey.latitude)
        defaults.set(longitude, forKey: StorageKey.longitude)
        defaults.set(date.timeIntervalSince1970, forKey: StorageKey.lastUpdateTime)
        defaults.set(try? JSONEncoder().encode(Array(directions.prefix(2))),
                     forKey: StorageKey.directionArrivals)
    }

    static func load() -> StationSnapshot? {
        guard let defaults,
              let name = defaults.string(forKey: StorageKey.nearestStation) else {
            return nil
        }
        let directions = defaults.data(forKey: StorageKey.directionArrivals)
            .flatMap { try? JSONDecoder().decode([StationDirectionSnapshot].self, from: $0) }
            ?? []
        return StationSnapshot(
            stationName: name,
            latitude: defaults.double(forKey: StorageKey.latitude),
            longitude: defaults.double(forKey: StorageKey.longitude),
            lastUpdate: Date(timeIntervalSince1970: defaults.double(forKey: StorageKey.lastUpdateTime)),
            directions: directions
        )
    }
}
