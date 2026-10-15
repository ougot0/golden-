import SwiftData
import SwiftUI
import SolarEngine
import GoldenHourCore

struct SessionDetailView: View {
    let session: PhotoSession
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditor = false
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if let place = session.place {
                    let day = SolarDayCalculator.solarDay(
                        for: LocalDate(session.start, in: place.timeZone),
                        coordinate: place.coordinate, timeZone: place.timeZone
                    )
                    SolarDayDetailSections(day: day, now: nil)
                } else {
                    Text("Aucun lieu associé : les heures du soleil ne peuvent pas être calculées pour cette séance.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .padding(20)
        }
        .instrumentBackground()
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showingEditor = true } label: { Label("Modifier", systemImage: "pencil") }
                    Button(role: .destructive) { confirmingDelete = true } label: { Label("Supprimer", systemImage: "trash") }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            SessionEditorView(session: session, initialDate: LocalDate(session.start, in: session.timeZone))
        }
        .confirmationDialog("Supprimer cette séance ?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                // Not saved immediately: this view may still read the object while it is dismissed.
                // SwiftData autosaves the deletion shortly after.
                dismiss()
                modelContext.delete(session)
                Task { await model.replanNotifications(context: modelContext) }
            }
        }
    }

    private var header: some View {
        let formatter = DateFormatter()
        formatter.timeZone = session.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMMyyyy")
        let time = SolarTimeFormatter(timeZone: session.timeZone, hourCycle: settings.hourCycle).time(session.start)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                InstrumentLabel(session.anchor.title)
                Text(time)
                    .font(.system(.largeTitle, design: .default, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(Palette.amberText)
                Text(formatter.string(from: session.start).capitalizingFirstLetter)
                    .foregroundStyle(Palette.ink)
                if let name = session.placeName {
                    Label(name, systemImage: "mappin.and.ellipse").foregroundStyle(Palette.inkSecondary)
                }
                if let reminder = session.reminder {
                    Label("Rappel : \(SolarStrings.reminder(reminder))", systemImage: "bell")
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            if !session.notes.isEmpty {
                InstrumentSection(title: "Notes") {
                    Text(session.notes).foregroundStyle(Palette.ink)
                }
            }
        }
    }
}
