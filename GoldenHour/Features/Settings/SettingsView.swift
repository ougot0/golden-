import SwiftData
import SwiftUI
import GoldenHourCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Affichage") {
                    Picker("Format horaire", selection: $settings.hourCycle) {
                        Text("Selon l'appareil").tag(HourCycle.system)
                        Text("24 h").tag(HourCycle.twentyFourHour)
                        Text("12 h").tag(HourCycle.twelveHour)
                    }
                    .accessibilityIdentifier("hourCyclePicker")
                    Picker("Thème", selection: $settings.theme) {
                        ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
                    }
                    LabeledContent("Unités", value: "Métriques · degrés")
                }

                Section("Données") {
                    NavigationLink("Notifications") { NotificationSettingsView() }
                    NavigationLink("Lieux favoris") { PlacesManagementView() }
                }

                Section("Informations") {
                    NavigationLink("Précision des calculs") { AccuracyView() }
                    NavigationLink("Confidentialité") { PrivacyPolicyView() }
                    NavigationLink("À propos") { AboutView() }
                }
            }
            .navigationTitle("Réglages")
            .onChange(of: settings.hourCycle) {
                // Notification texts contain formatted times.
                Task { await model.replanNotifications(context: modelContext) }
            }
        }
    }
}
