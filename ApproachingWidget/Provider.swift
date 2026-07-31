//
//  Provider.swift
//  ApproachingWidget
//
//  Reads the shared snapshot and emits per-minute entries so the
//  displayed time stays accurate. The widget never locates or queries.
//

import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StationEntry {
        StationEntry(date: Date(), stationName: "西二旗")
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (StationEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<StationEntry>) -> Void) {
        let name = AppGroupStore.load()?.stationName ?? "Approaching"
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(bySetting: .second, value: 0, of: now) ?? now

        var entries: [StationEntry] = []
        for minute in 0..<60 {
            if let date = calendar.date(byAdding: .minute, value: minute, to: start) {
                entries.append(StationEntry(date: date, stationName: name))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func currentEntry() -> StationEntry {
        StationEntry(date: Date(),
                     stationName: AppGroupStore.load()?.stationName ?? "Approaching")
    }
}
