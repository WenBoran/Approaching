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

    func nearestStation(latitude: Double, longitude: Double) -> Station? {
        allStations().min { lhs, rhs in
            distance(latitude, longitude, lhs.latitude, lhs.longitude)
                < distance(latitude, longitude, rhs.latitude, rhs.longitude)
        }
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
