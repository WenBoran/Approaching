import Foundation

struct DirectionArrival: Identifiable, Equatable {
    let id: Int
    let directionName: String
    let arrivalDates: [Date]

    func remainingMinutes(at referenceDate: Date) -> Int? {
        ArrivalSchedule.remainingMinutes(in: arrivalDates, at: referenceDate)
    }
}

struct NearestStationStatus: Equatable {
    let stationName: String
    let lineName: String
    let distanceInMeters: Double
    let directions: [DirectionArrival]
    let updatedAt: Date

    var formattedDistance: String {
        if distanceInMeters < 1_000 {
            return "约 \(Int(distanceInMeters.rounded())) 米"
        }
        return String(format: "约 %.1f 公里", distanceInMeters / 1_000)
    }
}
