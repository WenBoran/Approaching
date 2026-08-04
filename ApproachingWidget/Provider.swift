//
//  Provider.swift
//  ApproachingWidget
//
//  Reads the shared snapshot and emits per-minute entries so the
//  displayed time stays accurate. The widget never locates or queries.
//

import OSLog
import WidgetKit

struct Provider: TimelineProvider {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ApproachingWidget",
                                category: "Timeline")
    func placeholder(in context: Context) -> StationEntry {
        let now = Date()
        return StationEntry(
            date: now,
            stationName: "西二旗",
            directions: [
                StationDirectionSnapshot(
                    name: "昌平西山口",
                    arrivalDates: [now.addingTimeInterval(3 * 60), now.addingTimeInterval(9 * 60)]
                ),
                StationDirectionSnapshot(
                    name: "西土城",
                    arrivalDates: [now.addingTimeInterval(7 * 60), now.addingTimeInterval(13 * 60)]
                )
            ]
        )
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (StationEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<StationEntry>) -> Void) {
        let snapshot = AppGroupStore.load()
        if let snapshot {
            let departureCount = snapshot.directions.reduce(0) { $0 + $1.arrivalDates.count }
            logger.info("Widget snapshot loaded: station=\(snapshot.stationName, privacy: .public), lat=\(snapshot.latitude, privacy: .public), lon=\(snapshot.longitude, privacy: .public), directions=\(snapshot.directions.count, privacy: .public), departures=\(departureCount, privacy: .public)")
        } else {
            logger.warning("Widget snapshot is empty; open the App to refresh location")
        }
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.dateInterval(of: .minute, for: now)?.start ?? now
        logger.info("Widget timeline reference: now=\(now.description, privacy: .public), minuteStart=\(start.description, privacy: .public), snapshotUpdated=\(snapshot?.lastUpdate.description ?? "none", privacy: .public)")

        var entries: [StationEntry] = []
        for minute in 0..<60 {
            if let date = calendar.date(byAdding: .minute, value: minute, to: start) {
                entries.append(StationEntry(
                    date: date,
                    stationName: snapshot?.stationName ?? "Approaching",
                    directions: snapshot?.directions ?? []
                ))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func currentEntry() -> StationEntry {
        let snapshot = AppGroupStore.load()
        logger.debug("Widget snapshot requested; station=\(snapshot?.stationName ?? "none", privacy: .public), directions=\(snapshot?.directions.count ?? 0, privacy: .public)")
        return StationEntry(
            date: Date(),
            stationName: snapshot?.stationName ?? "Approaching",
            directions: snapshot?.directions ?? []
        )
    }
}
