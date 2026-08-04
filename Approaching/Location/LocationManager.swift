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
import OSLog

final class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Approaching",
                                category: "Location")

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastStationName: String?
    @Published var currentAddress: String?
    @Published var nearestStationStatus: NearestStationStatus?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        logger.debug("Requesting location permission; current status: \(self.manager.authorizationStatus.rawValue, privacy: .public)")
        manager.requestWhenInUseAuthorization()
    }

    func refreshLocation() {
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
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        logger.info("Location authorization changed: \(manager.authorizationStatus.rawValue, privacy: .public)")
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
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
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self else { return }
            if let error {
                self.logger.error("Reverse geocoding failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard let placemark = placemarks?.first else {
                self.logger.warning("Reverse geocoding returned no placemark")
                return
            }
            let address = [placemark.locality, placemark.subLocality, placemark.thoroughfare,
                           placemark.subThoroughfare]
                .compactMap { $0 }
                .joined()
            guard !address.isEmpty else { return }
            self.logger.info("Address resolved: \(address, privacy: .public)")
            DispatchQueue.main.async {
                self.currentAddress = address
            }
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        logger.error("Location request failed: \(error.localizedDescription, privacy: .public)")
    }
}
