import SwiftUI
import SwiftData

@main
struct KanjiMemoryApp: App {
    let modelContainer: ModelContainer
    @StateObject private var authManager = AuthManager.shared

    init() {
        do {
            let schema = Schema([
                KanjiProgress.self,
                RadicalProgress.self,
                VocabularyProgress.self,
                CachedImage.self,
                UserSettings.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ThemedContentView()
                .environmentObject(authManager)
        }
        .modelContainer(modelContainer)
    }
}

/// Wrapper view that applies the user's preferred color scheme
/// Uses @AppStorage for immediate reactivity when theme changes
struct ThemedContentView: View {
    @AppStorage("appTheme") private var appTheme = "system"

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil  // System default
        }
    }

    var body: some View {
        ContentView()
            .preferredColorScheme(colorScheme)
    }
}
