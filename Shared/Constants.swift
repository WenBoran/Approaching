//
//  Constants.swift
//  Approaching
//
//  Shared constants used by both the app and the widget.
//

import Foundation

enum AppConstants {
    /// App Group identifier shared between the app and the widget extension.
    static let appGroupID = "group.wbr.Approaching"

    /// WidgetKit `kind` identifier.
    static let widgetKind = "ApproachingWidget"
}

enum StorageKey {
    static let nearestStation = "nearestStation"
    static let latitude = "latitude"
    static let longitude = "longitude"
    static let lastUpdateTime = "lastUpdateTime"
    static let directionArrivals = "directionArrivals"
}
