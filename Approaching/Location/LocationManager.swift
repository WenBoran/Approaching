//
//  LocationManager.swift
//  Approaching
//
//  Requests permission, fetches the current location, and triggers
//  the nearest-station update.
//

import Foundation
import Combine
import CoreLocation
import MapKit
import OSLog

#if DEBUG
/// Hard-coded coordinates for debugging. Set `DebugLocation.active` to one of the
/// presets to bypass CoreLocation, or to `nil` to use the real device location.
enum DebugLocation {
    struct Preset {
        let label: String
        let latitude: Double
        let longitude: Double
    }

    static let active: Preset? = nil

    /// 3 lines, 6 directions.
    static let sanyuanqiao = Preset(label: "三元桥（3 条线换乘）", latitude: 39.95984, longitude: 116.45128)
    /// 3 lines including the airport express.
    static let dongzhimen = Preset(label: "东直门（含机场线）", latitude: 39.94162, longitude: 116.42857)
    /// Single line, 2 directions.
    static let wanshousi = Preset(label: "万寿寺（单线双向）", latitude: 39.94714, longitude: 116.30329)
    /// Terminus: a single direction only.
    static let tiantongyuanBei = Preset(label: "天通苑北（终点站单向）", latitude: 40.08209, longitude: 116.40679)
    /// Far-out station, useful for late-night / no-service states.
    static let universalResort = Preset(label: "环球度假区（远郊）", latitude: 39.84817, longitude: 116.67353)
    /// Outside the station database's city: exercises the very-long-distance layout.
    static let shanghai = Preset(label: "上海人民广场（超远距离）", latitude: 31.23037, longitude: 121.47370)
}
#endif

final class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    private var geocodingTask: Task<Void, Never>?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Approaching",
                                category: "Location")

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastStationName: String?
    @Published var currentAddress: String?
    @Published var nearestStationStatus: NearestStationStatus?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
#if DEBUG
        if let preset = DebugLocation.active {
            authorizationStatus = .authorizedWhenInUse
            apply(preset)
            return
        }
#endif
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Re-arm on every launch: iOS relaunches the app in the background for a
        // significant location change, and the delegate must be set by then.
        startMonitoringSignificantLocationChanges()
    }

    func requestPermission() {
        logger.debug("Requesting location permission; current status: \(self.manager.authorizationStatus.rawValue, privacy: .public)")
        manager.requestWhenInUseAuthorization()
    }

    /// Background wake-ups that keep the widget's coordinate fresh without the
    /// user opening the app. Requires "Always" authorization.
    func startMonitoringSignificantLocationChanges() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            logger.warning("Significant location change monitoring is unavailable on this device")
            return
        }
        guard manager.authorizationStatus == .authorizedAlways else {
            logger.debug("Skipping significant location change monitoring; status=\(self.manager.authorizationStatus.rawValue, privacy: .public)")
            return
        }
        manager.startMonitoringSignificantLocationChanges()
        logger.info("Monitoring significant location changes")
    }

    func refreshLocation() {
#if DEBUG
        if let preset = DebugLocation.active {
            apply(preset)
            return
        }
#endif
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            logger.debug("Requesting one-shot location update")
            manager.requestLocation()
        case .notDetermined:
            logger.debug("Location permission is undetermined; requesting permission first")
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            logger.warning("Cannot refresh location; authorization status: \(self.manager.authorizationStatus.rawValue, privacy: .public)")
        @unknown default:
            logger.warning("Cannot refresh location; unknown authorization status")
        }
    }

    deinit {
        geocodingTask?.cancel()
    }

#if DEBUG
    private func apply(_ preset: DebugLocation.Preset) {
        logger.info("Using debug location: \(preset.label, privacy: .public)")
        nearestStationStatus = StationService.updateNearestStationStatus(
            latitude: preset.latitude,
            longitude: preset.longitude
        )
        lastStationName = nearestStationStatus?.stationName
        currentAddress = preset.label
    }
#endif
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        logger.info("Location authorization changed: \(manager.authorizationStatus.rawValue, privacy: .public)")
        switch manager.authorizationStatus {
        case .authorizedAlways:
            manager.requestLocation()
            startMonitoringSignificantLocationChanges()
        case .authorizedWhenInUse:
            manager.requestLocation()
            // Ask to upgrade so the widget can be refreshed in the background.
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        logger.info("Location received: lat=\(latitude, privacy: .public), lon=\(longitude, privacy: .public), accuracy=\(location.horizontalAccuracy, privacy: .public)m, timestamp=\(location.timestamp.description, privacy: .public)")
        nearestStationStatus = StationService.updateNearestStationStatus(
            latitude: latitude,
            longitude: longitude
        )
        lastStationName = nearestStationStatus?.stationName
        reverseGeocode(location)
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocodingTask?.cancel()
        geocodingTask = Task { [weak self] in
            guard let self,
                  let request = MKReverseGeocodingRequest(location: location) else { return }

            do {
                let mapItems = try await request.mapItems
                guard let address = mapItems.first?.address?.fullAddress,
                      !address.isEmpty else {
                    self.logger.warning("Reverse geocoding returned no address")
                    return
                }
                guard !Task.isCancelled else { return }
                self.logger.info("Address resolved: \(address, privacy: .public)")
                await MainActor.run {
                    self.currentAddress = address
                }
            } catch is CancellationError {
                self.logger.debug("Reverse geocoding cancelled")
            } catch {
                self.logger.error("Reverse geocoding failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        logger.error("Location request failed: \(error.localizedDescription, privacy: .public)")
    }
}
