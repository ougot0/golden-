import SwiftData
import SwiftUI
import SolarEngine

@main
struct GoldenHourApp: App {
    private let container: ModelContainer
    @State private var model: AppModel

    init() {
        let launch = LaunchConfiguration.current
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: launch.isUITesting)
            container = try ModelContainer(for: SavedPlace.self, PhotoSession.self, configurations: configuration)
        } catch {
            // The store could not be opened (e.g. corrupted file). Fall back to memory so the app still
            // works; data entered in this session will not be persisted.
            container = try! ModelContainer(
                for: SavedPlace.self, PhotoSession.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        let settings = AppSettings(defaults: launch.defaults)
        if launch.isUITesting {
            settings.activePlace = launch.fixedPlace
        }
        _model = State(initialValue: AppModel(
            settings: settings,
            location: LocationService(),
            notifications: NotificationService()
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.settings)
                .preferredColorScheme(model.settings.theme.colorScheme)
        }
        .modelContainer(container)
    }
}

/// Options driven by launch arguments. Only UI tests pass `-ui-testing`: it isolates the run in a
/// separate defaults suite and an in-memory store, and uses a fixed place so no location prompt appears.
struct LaunchConfiguration {
    let isUITesting: Bool
    let defaults: UserDefaults

    static let current: LaunchConfiguration = {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        if isUITesting {
            let suite = "GoldenHour.UITests"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            return LaunchConfiguration(isUITesting: true, defaults: defaults)
        }
        return LaunchConfiguration(isUITesting: false, defaults: .standard)
    }()

    var fixedPlace: ActivePlace {
        ActivePlace(
            name: "Paris", subtitle: "Île-de-France, France",
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)!,
            timeZone: TimeZone(identifier: "Europe/Paris")!,
            timeZoneIsEstimated: false, source: .manual
        )
    }
}
