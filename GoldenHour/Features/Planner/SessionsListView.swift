import SwiftData
import SwiftUI
import GoldenHourCore

/// Upcoming and past photo sessions.
struct SessionsListView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhotoSession.start) private var sessions: [PhotoSession]
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ScrollView {
                        StatusMessage(
                            systemImage: "camera.aperture",
                            title: "Aucune séance planifiée",
                            message: "Planifiez un shooting à une date et un lieu, autour de l'heure dorée ou de l'heure bleue, avec un rappel avant le début.",
                            actionTitle: "Nouvelle séance",
                            action: { showingEditor = true }
                        )
                        .padding(20)
                    }
                } else {
                    list
                }
            }
            .instrumentBackground()
            .navigationTitle("Séances")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("Nouvelle séance", systemImage: "plus")
                    }
                    .accessibilityIdentifier("newSession")
                }
            }
            .sheet(isPresented: $showingEditor) {
                SessionEditorView(session: nil, initialDate: model.selectedDate)
            }
        }
    }

    private var list: some View {
        let now = Date.now
        let upcoming = sessions.filter { $0.start >= now.addingTimeInterval(-3600) }
        let past = sessions.filter { $0.start < now.addingTimeInterval(-3600) }.reversed()
        return List {
            Section("À venir") {
                if upcoming.isEmpty {
                    Text("Aucune séance à venir.").foregroundStyle(.secondary)
                }
                ForEach(upcoming) { session in
                    NavigationLink { SessionDetailView(session: session) } label: { SessionRow(session: session) }
                }
                .onDelete { delete(upcoming, at: $0) }
            }
            if !past.isEmpty {
                Section("Passées") {
                    ForEach(Array(past)) { session in
                        NavigationLink { SessionDetailView(session: session) } label: { SessionRow(session: session) }
                    }
                    .onDelete { delete(Array(past), at: $0) }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func delete(_ list: [PhotoSession], at offsets: IndexSet) {
        offsets.map { list[$0] }.forEach { modelContext.delete($0) }
        try? modelContext.save()
        Task { await model.replanNotifications(context: modelContext) }
    }
}

struct SessionRow: View {
    let session: PhotoSession
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title).font(.headline).foregroundStyle(Palette.ink)
            Text(dateLine).font(.subheadline).monospacedDigit().foregroundStyle(Palette.inkSecondary)
            HStack(spacing: 8) {
                Text(session.anchor.title)
                if let reminder = session.reminder {
                    Label(SolarStrings.reminder(reminder), systemImage: "bell")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.caption)
            .foregroundStyle(Palette.amberText)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.timeZone = session.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMMyyyy")
        let time = SolarTimeFormatter(timeZone: session.timeZone, hourCycle: settings.hourCycle).time(session.start)
        let place = session.placeName.map { " · \($0)" } ?? ""
        return "\(formatter.string(from: session.start)), \(time)\(place)"
    }
}
