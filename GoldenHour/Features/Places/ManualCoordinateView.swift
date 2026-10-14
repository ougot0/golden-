import SwiftUI
import SolarEngine
import GoldenHourCore

/// Entry of coordinates by hand, with time-zone selection. Works offline.
struct ManualCoordinateView: View {
    let onDone: (ActivePlace, _ saveAsFavorite: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var coordinateText = ""
    @State private var timeZoneIdentifier = TimeZone.current.identifier
    @State private var timeZoneConfirmed = false
    @State private var saveAsFavorite = true
    @State private var lookingUpTimeZone = false

    private var parsed: GeoCoordinate? { CoordinateParser.parse(coordinateText) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("48.8566, 2.3522", text: $coordinateText)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Coordonnées")
                        .accessibilityIdentifier("coordinateField")
                    if !coordinateText.isEmpty {
                        if let parsed {
                            Text(ActivePlace.format(parsed))
                                .font(.footnote).monospacedDigit()
                                .foregroundStyle(Palette.inkSecondary)
                        } else {
                            Text("Format non reconnu. Exemples : 48.8566, 2.3522 · 48°51'24\"N 2°21'08\"E")
                                .font(.footnote)
                                .foregroundStyle(Palette.warning)
                        }
                    }
                } header: {
                    Text("Coordonnées")
                } footer: {
                    Text("Latitude puis longitude, en degrés décimaux ou en degrés, minutes, secondes. Nord et Est positifs.")
                }

                Section("Nom") {
                    TextField("Ex. Belvédère de Belleville", text: $name)
                }

                Section {
                    NavigationLink {
                        TimeZonePickerView(selection: $timeZoneIdentifier)
                            .onDisappear { timeZoneConfirmed = true }
                    } label: {
                        LabeledContent("Fuseau horaire", value: timeZoneIdentifier)
                    }
                    Button {
                        lookUpTimeZone()
                    } label: {
                        HStack {
                            Text("Déterminer d'après les coordonnées")
                            if lookingUpTimeZone { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(parsed == nil || lookingUpTimeZone)
                } header: {
                    Text("Fuseau horaire")
                } footer: {
                    Text("Les heures sont affichées dans le fuseau du lieu. La détermination automatique nécessite une connexion ; sinon, choisissez le fuseau dans la liste.")
                }

                Section {
                    Toggle("Enregistrer dans les favoris", isOn: $saveAsFavorite)
                }
            }
            .navigationTitle("Coordonnées")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Utiliser") { submit() }
                        .disabled(parsed == nil)
                }
            }
        }
    }

    private func lookUpTimeZone() {
        guard let parsed else { return }
        lookingUpTimeZone = true
        Task {
            defer { lookingUpTimeZone = false }
            if let result = try? await PlaceGeocoder.reverse(parsed) {
                if let zone = result.timeZone {
                    timeZoneIdentifier = zone.identifier
                    timeZoneConfirmed = true
                }
                if name.isEmpty, let geocodedName = result.name {
                    name = geocodedName
                }
            }
        }
    }

    private func submit() {
        guard let parsed else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = ActivePlace(
            name: trimmed.isEmpty ? ActivePlace.format(parsed) : trimmed,
            subtitle: ActivePlace.format(parsed),
            coordinate: parsed,
            timeZone: TimeZone(identifier: timeZoneIdentifier) ?? .current,
            timeZoneIsEstimated: !timeZoneConfirmed,
            source: .manual
        )
        onDone(place, saveAsFavorite)
        dismiss()
    }
}

struct TimeZonePickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var filter = ""

    private var identifiers: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers
        guard !filter.isEmpty else { return all }
        let needle = filter.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: " ", with: "_")
        return all.filter {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).contains(needle)
        }
    }

    var body: some View {
        List(identifiers, id: \.self) { identifier in
            Button {
                selection = identifier
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(identifier.replacingOccurrences(of: "_", with: " "))
                        if let zone = TimeZone(identifier: identifier) {
                            Text(offsetDescription(zone)).font(.caption).foregroundStyle(Palette.inkSecondary)
                        }
                    }
                    Spacer()
                    if identifier == selection {
                        Image(systemName: "checkmark").foregroundStyle(Palette.amberText)
                    }
                }
            }
            .foregroundStyle(Palette.ink)
        }
        .searchable(text: $filter, prompt: "Ville ou région (ex. Paris, Tokyo)")
        .navigationTitle("Fuseau horaire")
    }

    private func offsetDescription(_ zone: TimeZone) -> String {
        let seconds = zone.secondsFromGMT()
        let sign = seconds >= 0 ? "+" : "−"
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        return minutes == 0 ? "UTC\(sign)\(hours)" : String(format: "UTC%@%d:%02d", sign, hours, minutes)
    }
}
