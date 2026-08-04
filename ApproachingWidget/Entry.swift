//
//  Entry.swift
//  ApproachingWidget
//

import WidgetKit

struct StationEntry: TimelineEntry {
    let date: Date
    let stationName: String
    let directions: [StationDirectionSnapshot]
}
