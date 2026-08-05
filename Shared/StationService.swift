//
//  StationService.swift
//  Approaching
//
//  Computes the nearest station, persists it to the App Group,
//  and asks WidgetKit to reload.
//

import Foundation
import OSLog
import WidgetKit

enum StationService {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Approaching",
        category: "Station"
    )

    @discardableResult
    static func updateNearestStationStatus(latitude: Double, longitude: Double,
                                           now: Date = Date()) -> NearestStationStatus? {
        guard let status = DatabaseManager.shared.nearestStationStatus(
            latitude: latitude,
            longitude: longitude,
            now: now
        ) else {
            logger.error("No station found for lat=\(latitude, privacy: .public), lon=\(longitude, privacy: .public)")
            return nil
        }
        saveWidgetSnapshot(
            for: status,
            latitude: latitude,
            longitude: longitude,
            now: now
        )
        return status
    }

    static func isFavorite(station: NearestStationStatus,
                           line: LineArrivals,
                           direction: DirectionArrival) -> Bool {
        AppGroupStore.favoriteDirections().contains(
            favorite(station: station, line: line, direction: direction)
        )
    }

    @discardableResult
    static func toggleFavorite(station: NearestStationStatus,
                               line: LineArrivals,
                               direction: DirectionArrival,
                               now: Date = Date()) -> Bool {
        let isFavorite = AppGroupStore.toggleFavorite(
            favorite(station: station, line: line, direction: direction)
        )
        if let snapshot = AppGroupStore.load() {
            saveWidgetSnapshot(
                for: station,
                latitude: snapshot.latitude,
                longitude: snapshot.longitude,
                now: now
            )
        }
        return isFavorite
    }

    @discardableResult
    static func updateNearestStation(latitude: Double, longitude: Double) -> String? {
        updateNearestStationStatus(latitude: latitude, longitude: longitude)?.stationName
    }

    private static func saveWidgetSnapshot(for status: NearestStationStatus,
                                           latitude: Double,
                                           longitude: Double,
                                           now: Date) {
        let selected = status.isCitySupported ? widgetDirections(for: status, now: now) : []

        AppGroupStore.save(
            stationName: status.stationName,
            latitude: latitude,
            longitude: longitude,
            directions: selected,
            date: now
        )
        let directionSummary = selected.map { direction in
            "\(direction.lineName)/\(direction.name)=\(direction.arrivalDates.count) departures, favorite=\(direction.isFavorite)"
        }.joined(separator: ", ")
        logger.info("Nearest station: \(status.stationName, privacy: .public), distance=\(status.distanceInMeters, privacy: .public)m, widgetDirections=[\(directionSummary, privacy: .public)]")
        WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
        logger.debug("Requested Widget timeline reload for \(AppConstants.widgetKind, privacy: .public)")
    }

    /// Flattens a station status into the directions the widget shows. Used by the app
    /// when writing the snapshot, and by the widget when it recomputes arrivals itself.
    static func widgetDirections(for status: NearestStationStatus,
                                 now: Date) -> [StationDirectionSnapshot] {
        let favorites = AppGroupStore.favoriteDirections()
        var seen = Set<String>()
        let all = status.lines.flatMap { line in
            line.directions.map { direction in
                let favorite = FavoriteDirection(
                    city: status.city,
                    stationName: status.stationName,
                    lineName: line.lineName,
                    directionName: direction.directionName
                )
                return StationDirectionSnapshot(
                    stationName: status.stationName,
                    lineName: line.lineName,
                    name: direction.directionName,
                    arrivalDates: direction.arrivalDates,
                    isFavorite: favorites.contains(favorite)
                )
            }
        }
        .filter { seen.insert("\($0.lineName)|\($0.name)").inserted }

        return widgetDirections(from: all, now: now)
    }

    /// Favorites at the nearest station come first (soonest departure first);
    /// remaining slots are filled with the soonest departures of the other directions.
    static func widgetDirections(from directions: [StationDirectionSnapshot],
                                 now: Date,
                                 limit: Int = AppConstants.widgetDirectionCount) -> [StationDirectionSnapshot] {
        let byDeparture = { (lhs: StationDirectionSnapshot, rhs: StationDirectionSnapshot) -> Bool in
            let lhsDate = ArrivalSchedule.nextDeparture(in: lhs.arrivalDates, at: now)
            let rhsDate = ArrivalSchedule.nextDeparture(in: rhs.arrivalDates, at: now)
            switch (lhsDate, rhsDate) {
            case let (lhs?, rhs?) where lhs != rhs:
                return lhs < rhs
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }
            if lhs.lineName != rhs.lineName {
                return lhs.lineName.localizedStandardCompare(rhs.lineName) == .orderedAscending
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        let favorites = directions.filter(\.isFavorite).sorted(by: byDeparture)
        let others = directions.filter { !$0.isFavorite }.sorted(by: byDeparture)
        return Array((favorites + others).prefix(limit))
    }

    private static func favorite(station: NearestStationStatus,
                                 line: LineArrivals,
                                 direction: DirectionArrival) -> FavoriteDirection {
        FavoriteDirection(
            city: station.city,
            stationName: station.stationName,
            lineName: line.lineName,
            directionName: direction.directionName
        )
    }
}
