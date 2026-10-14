import CoreLocation
import SwiftData
import SwiftUI
import UIKit
import SolarEngine
import GoldenHourCore

/// Chooses the active place: current position, search, favourites or typed coordinates.
struct PlacePickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedPlace.name) private var savedPlaces: [SavedPlace]
    @State private var search = PlaceSearchService()
    @State private var resolvingID: String?
    @State private var resolveError: String?
    @State private var showingManualEntry = false

    var body: some View {
        @Bindable var search = search
        NavigationStack {
            List {
                if search.query.isEmpty {
                    currentLocationSection
                    if let place = unsavedActivePlace {
                        Section {
                            Button {
                                save(place)
                            } label: {
                                Label("Enregistrer « \(place.name) » dans les favoris", systemImage: "star")
                            }
                            .disabled(isSaved(place))
                        }
                    }
                    favoritesSection
                    Section {
                        Button {
                            showingManualEntry = true
                        } label: {
                            Label("Saisir des coordonnées", systemImage: "number")
                        }
                    }
                } else {
                    searchResultsSection
                }
            }
            .navigationTitle("Lieu")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Ville, adresse, point d'intérêt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualCoordinateView { place, saveAsFavorite in
                    if saveAsFavorite {
                        let saved = save(place)
                        model.select(saved.activePlace ?? place)
                    } else {
                        model.select(place)
                    }
                    dismiss()
                }
            }
            .alert("Lieu introuvable", isPresented: Binding(
                get: { resolveError != nil }, set: { if !$0 { resolveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(resolveError ?? "")
            }
        }
    }

    // MARK: Sections

    private var currentLocationSection: some View {
        Section {
            Button {
                Task {
                    await model.useCurrentLocation()
                    if model.locationError == nil { dismiss() }
                }
            } label: {
                HStack {
                    Label("Utiliser ma position", systemImage: "location")
                    Spacer()
                    if model.location.isLocating { ProgressView() }
                }
            }
            .disabled(model.location.isLocating)
            .accessibilityIdentifier("useCurrentLocation")

            if let error = model.locationError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Palette.warning)
                if model.location.authorizationStatus == .denied {
                    Button("Ouvrir les Réglages") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
        } footer: {
            Text("La position n'est utilisée que sur l'appareil pour calculer les heures du soleil. Elle n'est jamais transmise à GoldenHour.")
        }
    }

    @ViewBuilder
    private var favoritesSection: some View {
        Section("Favoris") {
            if savedPlaces.isEmpty {
                Text("Aucun favori. Les lieux enregistrés restent disponibles hors ligne.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(savedPlaces) { saved in
                Button {
                    if let place = saved.activePlace {
                        model.select(place)
                        dismiss()
                    }
                } label: {
                    PlaceRow(name: saved.name, subtitle: saved.subtitle, isSelected: isSelected(saved))
                }
                .foregroundStyle(Palette.ink)
            }
            .onDelete { offsets in
                offsets.map { savedPlaces[$0] }.forEach { modelContext.delete($0) }
            }
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        Section {
            if let message = search.errorMessage {
                Text(message).font(.footnote).foregroundStyle(Palette.warning)
            } else if search.suggestions.isEmpty && !search.isSearching {
                Text("Aucun résultat").foregroundStyle(.secondary)
            }
            ForEach(search.suggestions) { suggestion in
                Button {
                    resolve(suggestion)
                } label: {
                    HStack {
                        PlaceRow(name: suggestion.title, subtitle: suggestion.subtitle, isSelected: false)
                        if resolvingID == suggestion.id { ProgressView() }
                    }
                }
                .foregroundStyle(Palette.ink)
                .disabled(resolvingID != nil)
            }
        } footer: {
            Text("Recherche fournie par Apple Plans. Une connexion est nécessaire.")
        }
    }

    // MARK: Actions

    private func resolve(_ suggestion: PlaceSearchService.Suggestion) {
        resolvingID = suggestion.id
        Task {
            defer { resolvingID = nil }
            do {
                let place = try await search.resolve(suggestion)
                model.select(place)
                dismiss()
            } catch {
                resolveError = "Impossible d'obtenir les coordonnées de ce lieu. Vérifiez votre connexion."
            }
        }
    }

    @discardableResult
    private func save(_ place: ActivePlace) -> SavedPlace {
        let saved = SavedPlace(
            name: place.name,
            subtitle: place.subtitle.isEmpty ? place.formattedCoordinate : place.subtitle,
            coordinate: place.coordinate,
            timeZone: place.timeZone,
            timeZoneIsEstimated: place.timeZoneIsEstimated
        )
        modelContext.insert(saved)
        if model.place == place, let active = saved.activePlace {
            model.select(active)
        }
        return saved
    }

    /// The active place when it is not already a favourite.
    private var unsavedActivePlace: ActivePlace? {
        guard let place = model.place else { return nil }
        if case .saved = place.source { return nil }
        return place
    }

    private func isSaved(_ place: ActivePlace) -> Bool {
        savedPlaces.contains {
            abs($0.latitude - place.coordinate.latitude) < 1e-5 && abs($0.longitude - place.coordinate.longitude) < 1e-5
        }
    }

    private func isSelected(_ saved: SavedPlace) -> Bool {
        if case .saved(let id) = model.place?.source { return id == saved.id }
        return false
    }
}

struct PlaceRow: View {
    let name: String
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(Palette.inkSecondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark").foregroundStyle(Palette.amberText)
                    .accessibilityLabel("Sélectionné")
            }
        }
        .contentShape(Rectangle())
    }
}
