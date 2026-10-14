import CoreLocation
import Foundation
import Observation
import SolarEngine

enum LocationError: LocalizedError {
    case denied
    case restricted
    case servicesDisabled
    case unavailable(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .denied:
            return "L'accès à la position a été refusé. Vous pouvez l'autoriser dans Réglages › GoldenHour › Position, ou choisir un lieu manuellement."
        case .restricted:
            return "L'accès à la position est restreint sur cet appareil (contrôle parental ou profil de gestion)."
        case .servicesDisabled:
            return "Le service de localisation est désactivé. Activez-le dans Réglages › Confidentialité et sécurité › Service de localisation."
        case .unavailable:
            return "Position introuvable pour le moment. Réessayez à l'extérieur ou choisissez un lieu manuellement."
        }
    }
}

/// Wraps `CLLocationManager` for one-shot positions and compass headings.
///
/// Battery: the app never runs continuous location updates. A position is requested once with
/// `requestLocation()`, and heading updates run only while the compass screen is visible.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var heading: CLHeading?
    private(set) var lastLocation: CLLocation?
    private(set) var isLocating = false

    @ObservationIgnored private let manager: CLLocationManager
    @ObservationIgnored private var locationContinuations: [CheckedContinuation<CLLocation, Error>] = []
    @ObservationIgnored private var authorizationContinuations: [CheckedContinuation<CLAuthorizationStatus, Never>] = []
    @ObservationIgnored private var headingClients = 0

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.headingFilter = 1
        manager.headingOrientation = .portrait
    }

    var headingAvailable: Bool { CLLocationManager.headingAvailable() }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// Requests a single position, asking for "When in use" permission first if needed.
    func requestCurrentLocation() async throws -> CLLocation {
        var status = authorizationStatus
        if status == .notDetermined {
            status = await requestAuthorization()
        }
        switch status {
        case .denied: throw LocationError.denied
        case .restricted: throw LocationError.restricted
        case .notDetermined: throw LocationError.denied
        default: break
        }
        isLocating = true
        defer { isLocating = false }
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuations.append(continuation)
            if locationContinuations.count == 1 {
                manager.requestLocation()
            }
        }
    }

    private func requestAuthorization() async -> CLAuthorizationStatus {
        await withCheckedContinuation { continuation in
            authorizationContinuations.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    /// Starts heading updates. Calls must be balanced with `stopHeadingUpdates()`.
    func startHeadingUpdates() {
        headingClients += 1
        guard headingClients == 1, headingAvailable else { return }
        manager.startUpdatingHeading()
        // A position is needed for `trueHeading`; one request is enough.
        if isAuthorized, lastLocation == nil {
            manager.requestLocation()
        }
    }

    func stopHeadingUpdates() {
        headingClients = max(0, headingClients - 1)
        guard headingClients == 0 else { return }
        manager.stopUpdatingHeading()
        heading = nil
    }

    // MARK: CLLocationManagerDelegate
    // CLLocationManager calls its delegate on the thread it was created on (here the main thread).

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            authorizationStatus = status
            guard status != .notDetermined else { return }
            let waiting = authorizationContinuations
            authorizationContinuations.removeAll()
            waiting.forEach { $0.resume(returning: status) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        MainActor.assumeIsolated {
            lastLocation = location
            let waiting = locationContinuations
            locationContinuations.removeAll()
            waiting.forEach { $0.resume(returning: location) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            // kCLErrorLocationUnknown is transient; Core Location keeps trying for requestLocation().
            if let clError = error as? CLError, clError.code == .locationUnknown { return }
            let mapped: LocationError
            if let clError = error as? CLError, clError.code == .denied {
                mapped = .denied
            } else {
                mapped = .unavailable(underlying: error)
            }
            let waiting = locationContinuations
            locationContinuations.removeAll()
            waiting.forEach { $0.resume(throwing: mapped) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        MainActor.assumeIsolated {
            heading = newHeading
        }
    }

    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        // Let iOS show its calibration prompt when the magnetometer needs it.
        true
    }
}
