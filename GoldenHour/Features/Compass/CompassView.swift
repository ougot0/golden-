import CoreLocation
import SwiftUI
import SolarEngine
import GoldenHourCore

/// Solar compass: sun path, sunrise/sunset directions and current sun azimuth, oriented with the
/// device heading when — and only when — that heading is reliable.
struct CompassView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @State private var isTracking = false
    @State private var showingPlacePicker = false
    @State private var displayedRotation: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                if let place = model.place {
                    content(place: place)
                        .padding(20)
                } else {
                    StatusMessage(
                        systemImage: "mappin.slash",
                        title: "Aucun lieu sélectionné",
                        message: "La boussole affiche la course du soleil pour un lieu.",
                        actionTitle: "Choisir un lieu",
                        action: { showingPlacePicker = true }
                    )
                    .padding(20)
                }
            }
            .instrumentBackground()
            .navigationTitle("Boussole solaire")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingPlacePicker) { PlacePickerView() }
        }
        .onAppear { startTracking() }
        .onDisappear { stopTracking() }
        .onChange(of: scenePhase) { _, phase in
            // Battery: the magnetometer only runs while the compass is on screen and the app is active.
            if phase == .active { startTracking() } else { stopTracking() }
        }
    }

    private func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        model.location.startHeadingUpdates()
    }

    private func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        model.location.stopHeadingUpdates()
    }

    @ViewBuilder
    private func content(place: ActivePlace) -> some View {
        let heading = model.location.heading
        let headingInfo = HeadingInfo(heading: heading, available: model.location.headingAvailable,
                                      authorized: model.location.isAuthorized)
        let day = SolarDayCalculator.solarDay(for: model.selectedDate, coordinate: place.coordinate, timeZone: place.timeZone)
        let path = SolarPath.samples(for: model.selectedDate, coordinate: place.coordinate, timeZone: place.timeZone, step: 300)

        VStack(alignment: .leading, spacing: 24) {
            HeadingStatusBanner(info: headingInfo, requestLocation: {
                Task { await model.useCurrentLocation() }
            })

            TimelineView(.periodic(from: .now, by: 10)) { context in
                let showSun = model.isShowingToday
                let sun = SolarCalculator.position(at: context.date, coordinate: place.coordinate)
                VStack(spacing: 20) {
                    CompassDial(
                        rotation: headingInfo.reliability.allowsLiveOrientation ? -displayedRotation : 0,
                        path: path,
                        sunrise: day.sunrise.map { SolarCalculator.position(at: $0, coordinate: place.coordinate).azimuth },
                        sunset: day.sunset.map { SolarCalculator.position(at: $0, coordinate: place.coordinate).azimuth },
                        sun: showSun ? sun : nil,
                        showsDeviceIndicator: headingInfo.reliability.allowsLiveOrientation
                    )
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity)
                    .animation(.easeOut(duration: 0.2), value: displayedRotation)

                    readings(sun: showSun ? sun : nil, day: day, place: place, info: headingInfo)
                }
            }
        }
        .onChange(of: heading?.timestamp) {
            guard let value = headingInfo.degrees else { return }
            displayedRotation = CompassMath.continuousAngle(previous: displayedRotation, next: value)
        }
    }

    @ViewBuilder
    private func readings(sun: SolarPosition?, day: SolarDay, place: ActivePlace, info: HeadingInfo) -> some View {
        let formatter = SolarTimeFormatter(timeZone: place.timeZone, hourCycle: settings.hourCycle)
        VStack(alignment: .leading, spacing: 12) {
            Hairline()
            if let sun {
                ValueRow(label: "Azimut du soleil",
                         value: "\(AngleFormatting.degrees(sun.azimuth)) \(CompassMath.cardinalAbbreviation(for: sun.azimuth))",
                         emphasized: true)
                ValueRow(label: "Élévation", value: AngleFormatting.degrees(sun.apparentElevation))
                if let heading = info.degrees, info.reliability.allowsLiveOrientation {
                    let delta = CompassMath.relativeBearing(target: sun.azimuth, heading: heading)
                    Text(turnInstruction(delta))
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                }
            } else {
                Text("Course du soleil pour la date sélectionnée dans l'onglet Aujourd'hui. La position en direct n'est affichée que pour aujourd'hui.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            if let rise = day.sunrise {
                ValueRow(label: "Lever",
                         value: AngleFormatting.degrees(SolarCalculator.position(at: rise, coordinate: place.coordinate).azimuth),
                         detail: formatter.time(rise))
            }
            if let set = day.sunset {
                ValueRow(label: "Coucher",
                         value: AngleFormatting.degrees(SolarCalculator.position(at: set, coordinate: place.coordinate).azimuth),
                         detail: formatter.time(set))
            }
            if let message = SolarStrings.condition(day.sunCondition) {
                Text(message).font(.footnote).foregroundStyle(Palette.inkSecondary)
            }
            Text("Azimuts mesurés depuis le nord géographique, dans le sens horaire.")
                .font(.caption)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private func turnInstruction(_ delta: Double) -> String {
        let amount = Int(abs(delta).rounded())
        if amount <= 3 { return "Vous faites face au soleil." }
        return delta > 0 ? "Tournez de \(amount)° vers la droite pour faire face au soleil."
                         : "Tournez de \(amount)° vers la gauche pour faire face au soleil."
    }
}

/// Heading and its reliability. A magnetic heading is used only when the true heading is unavailable,
/// and is then downgraded to "approximate" at best because magnetic declination is not corrected.
struct HeadingInfo {
    let degrees: Double?
    let reliability: HeadingReliability
    let isMagnetic: Bool
    let sensorAvailable: Bool
    let locationAuthorized: Bool

    init(heading: CLHeading?, available: Bool, authorized: Bool) {
        sensorAvailable = available
        locationAuthorized = authorized
        guard available, let heading, heading.headingAccuracy >= 0 else {
            degrees = nil
            reliability = .unavailable
            isMagnetic = false
            return
        }
        if heading.trueHeading >= 0 {
            degrees = heading.trueHeading
            isMagnetic = false
            reliability = HeadingReliability(headingAccuracy: heading.headingAccuracy)
        } else {
            degrees = heading.magneticHeading
            isMagnetic = true
            let base = HeadingReliability(headingAccuracy: heading.headingAccuracy)
            if case .good(let accuracy) = base {
                reliability = .approximate(accuracy: accuracy)
            } else {
                reliability = base
            }
        }
    }
}

private struct HeadingStatusBanner: View {
    let info: HeadingInfo
    let requestLocation: () -> Void

    var body: some View {
        switch info.reliability {
        case .good(let accuracy):
            Label("Orientation fiable · ±\(Int(accuracy.rounded()))°", systemImage: "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(Palette.inkSecondary)
        case .approximate(let accuracy):
            Label(info.isMagnetic
                  ? "Orientation approximative (nord magnétique, ±\(Int(accuracy.rounded()))°). Autorisez la position pour obtenir le nord géographique."
                  : "Orientation approximative · ±\(Int(accuracy.rounded()))°. Éloignez-vous des objets métalliques.",
                  systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(Palette.warning)
        case .needsCalibration(let accuracy):
            StatusMessage(
                systemImage: "gyroscope",
                title: "Boussole à calibrer",
                message: "Précision actuelle ±\(Int(accuracy.rounded()))° : trop faible pour orienter le cadran. Déplacez l'iPhone en formant un 8, loin des objets métalliques. Le cadran reste affiché nord en haut."
            )
        case .unavailable:
            if !info.sensorAvailable {
                StatusMessage(
                    systemImage: "location.slash",
                    title: "Pas de magnétomètre",
                    message: "Cet appareil ne fournit pas d'orientation. Le cadran est affiché nord en haut : orientez-le vous-même avec une boussole."
                )
            } else if !info.locationAuthorized {
                StatusMessage(
                    systemImage: "location.slash",
                    title: "Orientation indisponible",
                    message: "L'orientation de l'appareil nécessite l'accès à la position. Le cadran est affiché nord en haut.",
                    actionTitle: "Autoriser la position",
                    action: requestLocation
                )
            } else {
                Label("Recherche de l'orientation… Le cadran est affiché nord en haut.", systemImage: "location.north.line")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}
