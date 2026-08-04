import Foundation

struct DirectionArrival: Identifiable, Equatable {
    let id: Int
    let directionName: String
    let arrivalDates: [Date]

    func remainingMinutes(at referenceDate: Date) -> Int? {
        ArrivalSchedule.remainingMinutes(in: arrivalDates, at: referenceDate)
    }
}

struct LineArrivals: Identifiable, Equatable {
    let id: Int
    let lineName: String
    let directions: [DirectionArrival]
}

struct NearestStationStatus: Equatable {
    let stationName: String
    let city: String
    let distanceInMeters: Double
    let lines: [LineArrivals]
    let updatedAt: Date

    var directions: [DirectionArrival] {
        lines.flatMap(\.directions)
    }

    var formattedDistance: String {
        if distanceInMeters < 1_000 {
            return "约 \(Int(distanceInMeters.rounded())) 米"
        }
        return String(format: "约 %.1f 公里", distanceInMeters / 1_000)
    }
}
