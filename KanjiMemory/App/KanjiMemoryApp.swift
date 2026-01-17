import SwiftUI
import SwiftData

@main
struct KanjiMemoryApp: App {
    let modelContainer: ModelContainer

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
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
