import SwiftData
import SwiftUI
import SolarEngine

struct PlacesManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlace.name) private var places: [SavedPlace]

    var body: some View {
        List {
            if places.isEmpty {
                Text("Aucun lieu favori. Ajoutez-en depuis le sélecteur de lieu de l'onglet Aujourd'hui.")
                    .foregroundStyle(.secondary)
            }
            ForEach(places) { place in
                NavigationLink {
                    PlaceEditorView(place: place)
                } label: {
                    PlaceRow(name: place.name, subtitle: place.subtitle, isSelected: false)
                }
            }
            .onDelete { offsets in
                offsets.map { places[$0] }.forEach { modelContext.delete($0) }
            }
        }
        .navigationTitle("Lieux favoris")
        .toolbar { EditButton() }
    }
}

struct PlaceEditorView: View {
    @Bindable var place: SavedPlace
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        Form {
            Section("Nom") {
                TextField("Nom", text: $place.name)
            }
            Section("Position") {
                LabeledContent("Coordonnées") {
                    Text(place.coordinate.map(ActivePlace.format) ?? "—").monospacedDigit()
                }
                NavigationLink {
                    TimeZonePickerView(selection: Binding(
                        get: { place.timeZoneIdentifier },
                        set: {
                            place.timeZoneIdentifier = $0
                            place.timeZoneIsEstimated = false
                        }
                    ))
                } label: {
                    LabeledContent("Fuseau horaire", value: place.timeZoneIdentifier)
                }
                if place.timeZoneIsEstimated {
                    Text("Fuseau non vérifié : il a été repris de l'appareil. Choisissez le fuseau du lieu.")
                        .font(.footnote)
                        .foregroundStyle(Palette.warning)
                }
            }
            Section {
                Button("Utiliser ce lieu") {
                    if let active = place.activePlace { model.select(active) }
                }
                Button("Supprimer", role: .destructive) { confirmingDelete = true }
            }
        }
        .navigationTitle(place.name)
        .onDisappear {
            // Propagate edits to the active place if it is this favourite.
            if case .saved(let id) = model.place?.source, id == place.id, !place.isDeleted, let active = place.activePlace {
                model.select(active)
            }
        }
        .confirmationDialog("Supprimer ce lieu ?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                dismiss()
                modelContext.delete(place)
            }
        } message: {
            Text("Les séances déjà planifiées à ce lieu sont conservées.")
        }
    }
}
