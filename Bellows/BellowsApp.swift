import SwiftUI
import SwiftData
import CloudKit

@main
struct BellowsApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(createModelContainer())
    }
}

private func createModelContainer() -> ModelContainer {
    let schema = Schema([
        DayLog.self,
        ExerciseItem.self,
        ExerciseType.self,
        UnitType.self
    ])
    
    let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .automatic
    )
    
    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}
