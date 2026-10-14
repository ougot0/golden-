import SwiftData
import SwiftUI
import UIKit
import UserNotifications
import GoldenHourCore

struct NotificationSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var settings = settings
        Form {
            authorizationSection

            Section {
                Toggle("Alertes solaires", isOn: Binding(
                    get: { settings.solarNotificationsEnabled },
                    set: { enabled in
                        settings.solarNotificationsEnabled = enabled
                        if enabled { Task { await model.notifications.requestAuthorization(); await replan() } }
                    }
                ))
                .accessibilityIdentifier("solarAlertsToggle")
                if settings.solarNotificationsEnabled {
                    ForEach(SolarAlertKind.allCases) { kind in
                        Toggle(SolarStrings.alert(kind), isOn: Binding(
                            get: { settings.solarAlerts.contains(kind) },
                            set: { on in
                                if on { settings.solarAlerts.insert(kind) } else { settings.solarAlerts.remove(kind) }
                            }
                        ))
                    }
                    Picker("Prévenir", selection: $settings.solarAlertOffset) {
                        ForEach(ReminderOffset.allCases) { Text(SolarStrings.reminder($0)).tag($0) }
                    }
                }
            } header: {
                Text("Alertes solaires")
            } footer: {
                if let place = model.place {
                    Text("Pour le lieu sélectionné (\(place.name)), sur les 7 prochains jours. Les rappels des séances se règlent dans chaque séance.")
                } else {
                    Text("Choisissez d'abord un lieu dans l'onglet Aujourd'hui.")
                }
            }

            Section {
                LabeledContent("Notifications programmées", value: "\(model.notifications.scheduledCount)")
                if model.notifications.lastPlanDroppedItems {
                    Text("iOS limite à 64 le nombre de notifications en attente. Les plus lointaines seront programmées automatiquement à l'ouverture de l'app.")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                }
            } footer: {
                Text("Les notifications sont locales : elles sont calculées et programmées sur l'iPhone, sans serveur. Ouvrez GoldenHour au moins une fois par semaine pour que les alertes continuent d'être programmées.")
            }
        }
        .navigationTitle("Notifications")
        .task { await model.notifications.refreshAuthorization() }
        .onChange(of: settings.solarAlerts) { Task { await replan() } }
        .onChange(of: settings.solarAlertOffset) { Task { await replan() } }
        .onChange(of: settings.solarNotificationsEnabled) { Task { await replan() } }
    }

    @ViewBuilder
    private var authorizationSection: some View {
        switch model.notifications.authorizationStatus {
        case .denied:
            Section {
                Text("Les notifications de GoldenHour sont désactivées dans les Réglages d'iOS.")
                Button("Ouvrir les Réglages") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        case .notDetermined:
            Section {
                Button("Autoriser les notifications") {
                    Task { await model.notifications.requestAuthorization(); await replan() }
                }
            } footer: {
                Text("Nécessaire pour les alertes solaires et les rappels de séances.")
            }
        default:
            EmptyView()
        }
    }

    private func replan() async {
        await model.replanNotifications(context: modelContext)
    }
}
