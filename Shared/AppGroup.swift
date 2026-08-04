//
//  AppGroup.swift
//  Approaching
//
//  Reads/writes the shared snapshot in the App Group UserDefaults.
//  The app writes; the widget reads.
//

import Foundation

struct FavoriteDirection: Codable, Hashable {
    let city: String
    let stationName: String
    let lineName: String
    let directionName: String
}

struct StationDirectionSnapshot: Codable, Equatable {
    let lineName: String
    let name: String
    let arrivalDates: [Date]
    let isFavorite: Bool

    private enum CodingKeys: String, CodingKey {
        case lineName
        case name
        case arrivalDates
        case isFavorite
    }

    init(lineName: String, name: String, arrivalDates: [Date], isFavorite: Bool) {
        self.lineName = lineName
        self.name = name
        self.arrivalDates = arrivalDates
        self.isFavorite = isFavorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lineName = try container.decodeIfPresent(String.self, forKey: .lineName) ?? "地铁"
        name = try container.decode(String.self, forKey: .name)
        arrivalDates = try container.decode([Date].self, forKey: .arrivalDates)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }

    func remainingMinutes(at referenceDate: Date) -> Int? {
        ArrivalSchedule.remainingMinutes(in: arrivalDates, at: referenceDate)
    }
}

enum ArrivalSchedule {
    static func remainingMinutes(in arrivalDates: [Date], at referenceDate: Date) -> Int? {
        guard let arrivalDate = nextDeparture(in: arrivalDates, at: referenceDate) else {
            return nil
        }
        let minuteStart = Calendar.current.dateInterval(of: .minute, for: referenceDate)?.start
            ?? referenceDate
        return max(0, Int(ceil(arrivalDate.timeIntervalSince(minuteStart) / 60)))
    }

    static func nextDeparture(in arrivalDates: [Date], at referenceDate: Date) -> Date? {
        let minuteStart = Calendar.current.dateInterval(of: .minute, for: referenceDate)?.start
            ?? referenceDate
        return arrivalDates.first(where: { $0 >= minuteStart })
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
        defaults.set(try? JSONEncoder().encode(Array(directions.prefix(AppConstants.widgetDirectionCount))),
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

    static func favoriteDirections() -> Set<FavoriteDirection> {
        guard let data = defaults?.data(forKey: StorageKey.favoriteDirections),
              let favorites = try? JSONDecoder().decode([FavoriteDirection].self, from: data) else {
            return []
        }
        return Set(favorites)
    }

    @discardableResult
    static func toggleFavorite(_ favorite: FavoriteDirection) -> Bool {
        var favorites = favoriteDirections()
        let isFavorite: Bool
        if favorites.remove(favorite) != nil {
            isFavorite = false
        } else {
            favorites.insert(favorite)
            isFavorite = true
        }
        defaults?.set(try? JSONEncoder().encode(Array(favorites)),
                      forKey: StorageKey.favoriteDirections)
        return isFavorite
    }
}
