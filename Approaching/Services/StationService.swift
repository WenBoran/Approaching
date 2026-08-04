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
        let directions = status.directions.prefix(2).map {
            StationDirectionSnapshot(name: $0.directionName, arrivalDates: $0.arrivalDates)
        }
        AppGroupStore.save(stationName: status.stationName,
                           latitude: latitude,
                           longitude: longitude,
                           directions: directions,
                           date: now)
        let directionSummary = directions.map { direction in
            "\(direction.name)=\(direction.arrivalDates.count) departures"
        }.joined(separator: ", ")
        logger.info("Nearest station: \(status.stationName, privacy: .public), distance=\(status.distanceInMeters, privacy: .public)m, directions=[\(directionSummary, privacy: .public)]")
        WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
        logger.debug("Requested Widget timeline reload for \(AppConstants.widgetKind, privacy: .public)")
        return status
    }

    @discardableResult
    static func updateNearestStation(latitude: Double, longitude: Double) -> String? {
        updateNearestStationStatus(latitude: latitude, longitude: longitude)?.stationName
    }
}
