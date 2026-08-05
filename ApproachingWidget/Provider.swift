//
//  Provider.swift
//  ApproachingWidget
//
//  Recomputes arrivals from the bundled timetable using the last coordinate the
//  app stored, so the widget keeps working on later days without the app being
//  opened. Emits per-minute entries so the countdown stays accurate.
//

import Foundation
import OSLog
import WidgetKit

struct Provider: TimelineProvider {
    /// Metro service never starts before this hour; used as the wake-up point
    /// once the last train of the day has gone.
    private static let serviceStartHour = 4

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ApproachingWidget",
                                category: "Timeline")

    func placeholder(in context: Context) -> StationEntry {
        let now = Date()
        return StationEntry(
            date: now,
            stationName: "西二旗",
            directions: [
                StationDirectionSnapshot(
                    lineName: "13号线",
                    name: "昌平西山口",
                    arrivalDates: [now.addingTimeInterval(3 * 60), now.addingTimeInterval(9 * 60)],
                    isFavorite: true
                ),
                StationDirectionSnapshot(
                    lineName: "昌平线",
                    name: "西土城",
                    arrivalDates: [now.addingTimeInterval(7 * 60), now.addingTimeInterval(13 * 60)],
                    isFavorite: false
                )
            ]
        )
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (StationEntry) -> Void) {
        let now = Date()
        let resolved = resolve(now: now)
        completion(StationEntry(date: now,
                                stationName: resolved.stationName,
                                directions: resolved.directions,
                                isCityUnsupported: resolved.isCityUnsupported))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<StationEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.dateInterval(of: .minute, for: now)?.start ?? now
        let resolved = resolve(now: now)

        let lastDeparture = resolved.directions
            .flatMap(\.arrivalDates)
            .filter { $0 >= start }
            .max()

        let minuteCount: Int
        if let lastDeparture {
            let remaining = Int(ceil(lastDeparture.timeIntervalSince(start) / 60)) + 1
            minuteCount = min(60, max(1, remaining))
        } else {
            minuteCount = 1
        }

        var entries: [StationEntry] = []
        for minute in 0..<minuteCount {
            guard let date = calendar.date(byAdding: .minute, value: minute, to: start) else {
                continue
            }
            entries.append(StationEntry(
                date: date,
                stationName: resolved.stationName,
                directions: resolved.directions,
                isCityUnsupported: resolved.isCityUnsupported
            ))
        }

        // While trains are still running, reload at the end of the timeline.
        // Once service is over, sleep until the next morning instead of burning
        // refreshes on a screen that cannot change.
        let policy: TimelineReloadPolicy = lastDeparture == nil
            ? .after(nextServiceStart(after: now, calendar: calendar))
            : .atEnd

        logger.info("Widget timeline: station=\(resolved.stationName, privacy: .public), directions=\(resolved.directions.count, privacy: .public), entries=\(entries.count, privacy: .public), lastDeparture=\(lastDeparture?.description ?? "none", privacy: .public)")
        completion(Timeline(entries: entries, policy: policy))
    }

    /// Recomputes from the bundled timetable; falls back to the snapshot the app
    /// wrote if the coordinate or the database is unavailable.
    private func resolve(now: Date) -> Resolved {
        if let coordinate = AppGroupStore.lastCoordinate(),
           let status = DatabaseManager.shared.nearestStationStatus(
               latitude: coordinate.latitude,
               longitude: coordinate.longitude,
               now: now
           ) {
            guard status.isCitySupported else {
                logger.info("Nearest station \(status.stationName, privacy: .public) is \(status.distanceInMeters, privacy: .public)m away; treating the city as unsupported")
                return Resolved(stationName: status.stationName,
                                directions: [],
                                isCityUnsupported: true)
            }
            return Resolved(stationName: status.stationName,
                            directions: StationService.widgetDirections(for: status, now: now))
        }

        guard let snapshot = AppGroupStore.load() else {
            logger.warning("No coordinate and no snapshot; open the App to grant location access")
            return Resolved(stationName: "Approaching", directions: [])
        }
        logger.warning("Timetable lookup failed; falling back to the stored snapshot")
        return Resolved(stationName: snapshot.stationName, directions: snapshot.directions)
    }

    private struct Resolved {
        let stationName: String
        let directions: [StationDirectionSnapshot]
        var isCityUnsupported = false
    }

    private func nextServiceStart(after date: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = Self.serviceStartHour
        components.minute = 0
        components.second = 0
        guard let today = calendar.date(from: components) else {
            return date.addingTimeInterval(3600)
        }
        if today > date { return today }
        return calendar.date(byAdding: .day, value: 1, to: today)
            ?? date.addingTimeInterval(3600)
    }
}
