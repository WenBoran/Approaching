//
//  Entry.swift
//  ApproachingWidget
//

import WidgetKit

struct StationEntry: TimelineEntry {
    let date: Date
    let stationName: String
    let directions: [StationDirectionSnapshot]
    /// The nearest station is too far away, i.e. the user is in a city the
    /// bundled timetable does not cover.
    var isCityUnsupported: Bool = false
}
