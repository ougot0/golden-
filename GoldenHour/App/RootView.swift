import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var wasShowingToday = true

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            DashboardView()
                .tabItem { Label("Aujourd'hui", systemImage: "sun.horizon") }
                .tag(AppTab.today)
            SolarCalendarView()
                .tabItem { Label("Calendrier", systemImage: "calendar") }
                .tag(AppTab.calendar)
            CompassView()
                .tabItem { Label("Boussole", systemImage: "location.north.line") }
                .tag(AppTab.compass)
            SessionsListView()
                .tabItem { Label("Séances", systemImage: "camera.aperture") }
                .tag(AppTab.sessions)
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(Palette.amberText)
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                // Keep "today" current when the app comes back after midnight, unless the user was
                // looking at another date on purpose.
                if wasShowingToday { model.selectedDate = model.today }
                Task { await model.replanNotifications(context: modelContext) }
            case .background:
                wasShowingToday = model.isShowingToday
            default:
                break
            }
        }
        .onChange(of: model.settings.activePlace) {
            Task { await model.replanNotifications(context: modelContext) }
        }
    }
}
