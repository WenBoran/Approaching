//
//  DatabaseManager.swift
//  Approaching
//
//  Reads the bundled metro.sqlite and finds the nearest station.
//

import Foundation
import SQLite3

final class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?

    private init() {
        openDatabase()
    }

    deinit {
        if db != nil { sqlite3_close(db) }
    }

    private func openDatabase() {
        guard let url = Bundle.main.url(forResource: "metro", withExtension: "sqlite") else {
            return
        }
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            db = nil
        }
    }

    func allStations() -> [Station] {
        guard let db else { return [] }
        let sql = "SELECT id, name, city, latitude, longitude FROM station;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var stations: [Station] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let namePtr = sqlite3_column_text(statement, 1),
                  let cityPtr = sqlite3_column_text(statement, 2) else {
                continue
            }
            let station = Station(
                id: Int(sqlite3_column_int(statement, 0)),
                name: String(cString: namePtr),
                city: String(cString: cityPtr),
                latitude: sqlite3_column_double(statement, 3),
                longitude: sqlite3_column_double(statement, 4)
            )
            stations.append(station)
        }
        return stations
    }

    func nearestStationStatus(latitude: Double, longitude: Double,
                              now: Date = Date()) -> NearestStationStatus? {
        guard let station = nearestStation(latitude: latitude, longitude: longitude),
              let db else { return nil }

        let interchangeStations = stations(
            matching: station,
            withinMeters: 200
        )
        // An interchange is stored as one `station` row per line, so merge every row
        // that shares the same name into a single per-line entry.
        var lineNames: [Int: String] = [:]
        var lineDirections: [Int: [DirectionArrival]] = [:]
        for interchange in interchangeStations {
            guard let line = lineInfo(for: interchange.id, db: db) else { continue }
            let directions = nextArrivals(for: interchange.id, now: now, db: db)
            guard !directions.isEmpty else { continue }
            lineNames[line.id] = line.name
            var merged = lineDirections[line.id, default: []]
            for direction in directions
            where !merged.contains(where: { $0.directionName == direction.directionName }) {
                merged.append(direction)
            }
            lineDirections[line.id] = merged
        }

        let lines = lineNames.map { lineID, lineName in
            LineArrivals(
                id: lineID,
                lineName: lineName,
                directions: lineDirections[lineID, default: []]
                    .sorted { $0.directionName.localizedStandardCompare($1.directionName) == .orderedAscending }
            )
        }
        .sorted { $0.lineName.localizedStandardCompare($1.lineName) == .orderedAscending }

        return NearestStationStatus(
            stationName: station.name,
            city: station.city,
            distanceInMeters: distance(latitude, longitude, station.latitude, station.longitude),
            lines: lines,
            updatedAt: now
        )
    }

    func nearestStation(latitude: Double, longitude: Double) -> Station? {
        allStations().min { lhs, rhs in
            distance(latitude, longitude, lhs.latitude, lhs.longitude)
                < distance(latitude, longitude, rhs.latitude, rhs.longitude)
        }
    }

    private func stations(matching station: Station, withinMeters radius: Double) -> [Station] {
        allStations().filter { candidate in
            candidate.city == station.city
                && candidate.name == station.name
                && distance(
                    station.latitude,
                    station.longitude,
                    candidate.latitude,
                    candidate.longitude
                ) <= radius
        }
    }

    private func lineInfo(for stationID: Int, db: OpaquePointer) -> (id: Int, name: String)? {
        let sql = "SELECT l.id, l.name FROM station s JOIN line l ON l.id = s.line_id WHERE s.id = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(stationID))
        guard sqlite3_step(statement) == SQLITE_ROW,
              let name = sqlite3_column_text(statement, 1) else { return nil }
        return (Int(sqlite3_column_int(statement, 0)), String(cString: name))
    }

    private func nextArrivals(for stationID: Int, now: Date,
                              db: OpaquePointer) -> [DirectionArrival] {
        let sql = """
        SELECT d.id, d.name, ss.service_type_key, p.departure_time
        FROM direction d
        JOIN service_schedule ss ON ss.direction_id = d.id
        JOIN departure p ON p.schedule_id = ss.id
        WHERE d.station_id = ?
        ORDER BY d.id, p.sequence;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(stationID))

        let calendarWeekday = Calendar.current.component(.weekday, from: now)
        let weekday = (calendarWeekday + 5) % 7 + 1
        var directionNames: [Int: String] = [:]
        var departureDates: [Int: Set<Date>] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let directionID = Int(sqlite3_column_int(statement, 0))
            guard let directionNamePtr = sqlite3_column_text(statement, 1),
                  let serviceKeyPtr = sqlite3_column_text(statement, 2),
                  let timePtr = sqlite3_column_text(statement, 3) else { continue }
            let serviceKey = String(cString: serviceKeyPtr)
            guard serviceKeyApplies(serviceKey, weekday: weekday) else { continue }

            let directionName = String(cString: directionNamePtr)
            let departureTime = String(cString: timePtr)
            directionNames[directionID] = directionName
            guard let departureDate = departureDate(for: departureTime, on: now) else { continue }
            departureDates[directionID, default: []].insert(departureDate)
        }

        return directionNames.keys.sorted().map { directionID in
            DirectionArrival(
                id: directionID,
                directionName: directionNames[directionID] ?? "",
                arrivalDates: departureDates[directionID, default: []].sorted()
            )
        }
    }

    private func serviceKeyApplies(_ serviceKey: String, weekday: Int) -> Bool {
        guard serviceKey.hasPrefix("weekday_") else { return false }
        let applicableDays = serviceKey
            .dropFirst("weekday_".count)
            .split(separator: "_")
            .compactMap { Int(String($0)) }
        return applicableDays.contains(weekday)
    }

    private func departureDate(for time: String, on serviceDate: Date) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, parts[0] >= 0, parts[0] <= 24,
              parts[1] >= 0, parts[1] < 60 else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = .current
        var components = calendar.dateComponents([.year, .month, .day], from: serviceDate)
        let isNextDay = parts[0] == 24
        components.hour = isNextDay ? 0 : parts[0]
        components.minute = parts[1]
        components.second = 0
        guard let date = calendar.date(from: components) else { return nil }
        return isNextDay ? calendar.date(byAdding: .day, value: 1, to: date) : date
    }

    /// Haversine distance in meters.
    private func distance(_ lat1: Double, _ lon1: Double,
                          _ lat2: Double, _ lon2: Double) -> Double {
        let earthRadius = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180)
            * sin(dLon / 2) * sin(dLon / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
